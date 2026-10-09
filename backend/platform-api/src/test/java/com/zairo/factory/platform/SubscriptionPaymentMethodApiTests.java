package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.platform.TestPayments.FailureController;
import com.zairo.factory.subscriptions.SubscriptionRenewalService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

/**
 * The stored card (display data + recurring profile) and the renewal paths
 * around it: auto-charge when the provider can, hosted checkout when it
 * cannot (the Freedom Pay situation until its recurring-charge docs are
 * confirmed).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class, TestClock.class})
class SubscriptionPaymentMethodApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private SubscriptionRenewalService renewalService;

    @Autowired
    private MutableClock clock;

    @Autowired
    private FailureController failureController;

    @AfterEach
    void resetProvider() {
        failureController.noRecurringCharge = false;
        failureController.pendingNextCharge = false;
    }

    @Test
    void theCardUsedForTheUpgradeIsStoredShownAndCanBeRemoved() {
        Registered owner = owner("pm-show");
        assertThat(paymentMethod(owner).get("saved")).isEqualTo(false);

        upgrade(owner);
        Map<?, ?> card = paymentMethod(owner);
        assertThat(card.get("saved")).isEqualTo(true);
        assertThat(card.get("last4")).isEqualTo("4242");
        assertThat(card.get("brand")).isEqualTo("VISA");
        assertThat(card.get("autoRenew")).isEqualTo(true);

        assertThat(exchange(owner, "/api/v1/subscriptions/me/payment-method", HttpMethod.DELETE, Void.class)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(paymentMethod(owner).get("saved")).isEqualTo(false);
        // Removing twice is fine.
        assertThat(exchange(owner, "/api/v1/subscriptions/me/payment-method", HttpMethod.DELETE, Void.class)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }

    @Test
    void withoutAStoredCardTheRenewalIsNotChargedAndTheOwnerGetsAGracePeriod() {
        Registered owner = owner("pm-removed");
        Instant periodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());
        UUID upgradeChargeId = latestChargeId(owner);
        exchange(owner, "/api/v1/subscriptions/me/payment-method", HttpMethod.DELETE, Void.class);

        clock.advanceTo(periodEnd.plus(1, ChronoUnit.DAYS));
        renewalService.renewDueSubscriptions();

        Map<?, ?> sub = getMine(owner);
        assertThat(sub.get("status")).isEqualTo("PAST_DUE");
        assertThat(sub.get("plan")).isEqualTo("PRO");
        assertThat(failureController.chargeAttempts).doesNotContainKey(upgradeChargeId);
        assertThat(charges(owner)).hasSize(1);
    }

    @Test
    void aProviderThatCannotAutoChargeSendsTheOwnerToCheckoutAndTheWebhookRenewsPro() {
        failureController.noRecurringCharge = true;
        Registered owner = owner("pm-checkout");
        Instant periodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());
        assertThat(paymentMethod(owner).get("autoRenew")).isEqualTo(false);

        clock.advanceTo(periodEnd.plus(1, ChronoUnit.DAYS));
        renewalService.renewDueSubscriptions();
        assertThat(getMine(owner).get("status")).isEqualTo("PAST_DUE");
        assertThat(failureController.chargeAttempts).isEmpty();

        // "Fix": the provider leaves the charge pending, so the owner is sent to its checkout page.
        failureController.pendingNextCharge = true;
        ResponseEntity<Map> fix = exchange(owner, "/api/v1/subscriptions/retry-charge", HttpMethod.POST, Map.class);
        assertThat(fix.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(fix.getBody().get("checkoutUrl").toString()).startsWith("https://pay.test/checkout/");
        assertThat(fix.getBody().get("status")).isEqualTo("PAST_DUE");

        // A second click while that checkout is fresh does not start another payment.
        failureController.pendingNextCharge = true;
        assertThat(exchange(owner, "/api/v1/subscriptions/retry-charge", HttpMethod.POST, Map.class)
                .getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // The provider's webhook, not the redirect, renews the subscription.
        UUID chargeId = latestChargeId(owner);
        assertThat(postWebhook(chargeId, "1").getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> renewed = getMine(owner);
        assertThat(renewed.get("status")).isEqualTo("ACTIVE");
        assertThat(renewed.get("gracePeriodEndsAt")).isNull();
        assertThat(Instant.parse(renewed.get("currentPeriodEnd").toString())).isAfter(periodEnd);
    }

    @Test
    void aFailedCheckoutWebhookLeavesTheSubscriptionPastDue() {
        failureController.noRecurringCharge = true;
        Registered owner = owner("pm-checkout-fail");
        Instant periodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());
        clock.advanceTo(periodEnd.plus(1, ChronoUnit.DAYS));
        renewalService.renewDueSubscriptions();

        failureController.pendingNextCharge = true;
        exchange(owner, "/api/v1/subscriptions/retry-charge", HttpMethod.POST, Map.class);
        postWebhook(latestChargeId(owner), "0");

        assertThat(getMine(owner).get("status")).isEqualTo("PAST_DUE");
    }

    @Test
    void theDailyRetryDoesNotChargeSilentlyWhenTheProviderCannot() {
        failureController.noRecurringCharge = true;
        Registered owner = owner("pm-noretry");
        Instant periodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());
        clock.advanceTo(periodEnd.plus(1, ChronoUnit.DAYS));
        renewalService.renewDueSubscriptions();

        clock.advanceTo(clock.instant().plus(1, ChronoUnit.DAYS));
        renewalService.retryPastDueSubscriptions();

        assertThat(getMine(owner).get("status")).isEqualTo("PAST_DUE");
        assertThat(failureController.chargeAttempts).isEmpty();
        assertThat(charges(owner)).hasSize(1);
    }

    // --- helpers -----------------------------------------------------------------------------------------------

    private Registered owner(String prefix) {
        return TestAuth.registerOwner(restTemplate, prefix + "-" + UUID.randomUUID() + "@example.com");
    }

    private <T> ResponseEntity<T> exchange(Registered owner, String path, HttpMethod method, Class<T> type) {
        return restTemplate.exchange(path, method, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())),
                type);
    }

    private Map<?, ?> paymentMethod(Registered owner) {
        return exchange(owner, "/api/v1/subscriptions/me/payment-method", HttpMethod.GET, Map.class).getBody();
    }

    private Map<?, ?> getMine(Registered owner) {
        return exchange(owner, "/api/v1/subscriptions/me", HttpMethod.GET, Map.class).getBody();
    }

    private Map<?, ?> upgrade(Registered owner) {
        ResponseEntity<Map> response = exchange(owner, "/api/v1/subscriptions/upgrade", HttpMethod.POST, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private java.util.List<?> charges(Registered owner) {
        return exchange(owner, "/api/v1/subscriptions/me/charges", HttpMethod.GET, java.util.List.class).getBody();
    }

    private UUID latestChargeId(Registered owner) {
        return UUID.fromString(((Map<?, ?>) charges(owner).get(0)).get("id").toString());
    }

    /** A signed Result-notify webhook for this charge (test config: script {@code result.php}, empty secret). */
    private ResponseEntity<String> postWebhook(UUID chargeId, String pgResult) {
        Map<String, String> fields = new TreeMap<>();
        fields.put("pg_order_id", "subscription-charge:" + chargeId);
        fields.put("pg_payment_id", "fp_" + chargeId);
        fields.put("pg_amount", "29.00");
        fields.put("pg_currency", "USD");
        fields.put("pg_result", pgResult);
        StringBuilder toSign = new StringBuilder("result.php");
        fields.values().forEach(v -> toSign.append(';').append(v));
        toSign.append(';');
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        fields.forEach(form::add);
        form.add("pg_sig", md5(toSign.toString()));
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        return restTemplate.postForEntity("/webhooks/payments/freedompay", new HttpEntity<>(form, headers),
                String.class);
    }

    private static String md5(String text) {
        try {
            byte[] hash = MessageDigest.getInstance("MD5").digest(text.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : hash) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16)).append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
