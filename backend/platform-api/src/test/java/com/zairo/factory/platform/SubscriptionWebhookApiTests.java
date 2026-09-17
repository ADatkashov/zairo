package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.paymentprovider.PaymentProviderName;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.subscriptions.Subscription;
import com.zairo.factory.subscriptions.SubscriptionCharge;
import com.zairo.factory.subscriptions.SubscriptionChargeRepository;
import com.zairo.factory.subscriptions.SubscriptionChargeStatus;
import com.zairo.factory.subscriptions.SubscriptionPlan;
import com.zairo.factory.subscriptions.SubscriptionRepository;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;
import java.util.UUID;
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
 * Against a real Postgres (Testcontainers): the same Freedom Pay webhook
 * endpoint as {@link PaymentWebhookApiTests}, this time confirming a {@code
 * subscription-charge:} order id -- the flow that was completely broken
 * before Phase 0 stabilization (see {@code FreedomPayOrderIds}' own doc
 * comment): a subscription-upgrade charge's webhook used to embed a {@code
 * SubscriptionCharge} id under the booking-payment prefix, so it could
 * never resolve in {@code payments.PaymentRepository} and always came back
 * "unknown payment" -- a real-provider PRO upgrade could never actually
 * activate. A {@code SubscriptionCharge} row is inserted directly in
 * PENDING (same "bypass the always-synchronous mock provider" reasoning
 * {@link PaymentWebhookApiTests} uses for {@code Payment}) to put the
 * system in the state a real Freedom Pay checkout would.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class SubscriptionWebhookApiTests {

    private static final String SCRIPT_NAME = "result.php";
    private static final String SECRET_KEY = "";

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private SubscriptionRepository subscriptionRepository;

    @Autowired
    private SubscriptionChargeRepository subscriptionChargeRepository;

    @Test
    void aValidWebhookActivatesProExactlyOnce() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-webhook-owner-" + runId + "@example.com");
        Subscription subscription = getOrCreateSubscription(owner);
        assertThat(subscription.getPlan()).isEqualTo(SubscriptionPlan.FREE);
        UUID chargeId = createPendingCharge(subscription.getId(), SubscriptionPlan.PRO.monthlyPrice, "USD");

        ResponseEntity<String> response = postWebhook(signedFields(chargeId, "29.00", "USD", "1"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("<pg_status>ok</pg_status>");

        Subscription afterFirst = subscriptionRepository.findById(subscription.getId()).orElseThrow();
        assertThat(afterFirst.getPlan()).isEqualTo(SubscriptionPlan.PRO);
        assertThat(subscriptionChargeRepository.findById(chargeId).orElseThrow().getStatus())
                .isEqualTo(SubscriptionChargeStatus.SUCCEEDED);
        Instant firstPeriodStart = afterFirst.getCurrentPeriodStart();

        // Scenario D, second half: the exact same webhook delivered again
        // (Freedom Pay retries Result-notify up to 4x/2h) must not
        // re-activate/re-extend PRO a second time.
        ResponseEntity<String> replay = postWebhook(signedFields(chargeId, "29.00", "USD", "1"));
        assertThat(replay.getStatusCode()).isEqualTo(HttpStatus.OK);

        Subscription afterReplay = subscriptionRepository.findById(subscription.getId()).orElseThrow();
        assertThat(afterReplay.getPlan()).isEqualTo(SubscriptionPlan.PRO);
        assertThat(afterReplay.getCurrentPeriodStart()).isEqualTo(firstPeriodStart);
    }

    @Test
    void aFailedPaymentWebhookLeavesTheSubscriptionOnFreeNotPro() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-webhook-fail-" + runId + "@example.com");
        Subscription subscription = getOrCreateSubscription(owner);
        UUID chargeId = createPendingCharge(subscription.getId(), SubscriptionPlan.PRO.monthlyPrice, "USD");

        ResponseEntity<String> response = postWebhook(signedFields(chargeId, "29.00", "USD", "0"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);

        Subscription after = subscriptionRepository.findById(subscription.getId()).orElseThrow();
        assertThat(after.getPlan()).isEqualTo(SubscriptionPlan.FREE);
        assertThat(subscriptionChargeRepository.findById(chargeId).orElseThrow().getStatus())
                .isEqualTo(SubscriptionChargeStatus.FAILED);
    }

    @Test
    void anAmountMismatchIsRejectedWithoutActivatingPro() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-webhook-mismatch-" + runId + "@example.com");
        Subscription subscription = getOrCreateSubscription(owner);
        UUID chargeId = createPendingCharge(subscription.getId(), SubscriptionPlan.PRO.monthlyPrice, "USD");

        ResponseEntity<String> response = postWebhook(signedFields(chargeId, "1.00", "USD", "1"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);

        Subscription after = subscriptionRepository.findById(subscription.getId()).orElseThrow();
        assertThat(after.getPlan()).isEqualTo(SubscriptionPlan.FREE);
        assertThat(subscriptionChargeRepository.findById(chargeId).orElseThrow().getStatus())
                .isEqualTo(SubscriptionChargeStatus.PENDING);
    }

    private Subscription getOrCreateSubscription(Registered owner) {
        // Touch GET /subscriptions/me to trigger the lazy-create, then read
        // the row back directly -- the DTO doesn't expose the raw entity.
        restTemplate.exchange("/api/v1/subscriptions/me", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        return subscriptionRepository.findByOwnerUserId(owner.userId()).orElseThrow();
    }

    private UUID createPendingCharge(UUID subscriptionId, BigDecimal amount, String currency) {
        SubscriptionCharge charge = new SubscriptionCharge(UUID.randomUUID(), subscriptionId, amount, currency,
                PaymentProviderName.FREEDOMPAY, null, Instant.now());
        return subscriptionChargeRepository.save(charge).getId();
    }

    private ResponseEntity<String> postWebhook(MultiValueMap<String, String> form) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        return restTemplate.postForEntity("/webhooks/payments/freedompay", new HttpEntity<>(form, headers),
                String.class);
    }

    private MultiValueMap<String, String> signedFields(UUID chargeId, String amount, String currency,
            String pgResult) {
        Map<String, String> fields = new TreeMap<>();
        fields.put("pg_order_id", "subscription-charge:" + chargeId);
        fields.put("pg_payment_id", "fp_" + chargeId);
        fields.put("pg_amount", amount);
        fields.put("pg_currency", currency);
        fields.put("pg_result", pgResult);
        String signature = computeSignature(SCRIPT_NAME, fields, SECRET_KEY);

        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        fields.forEach(form::add);
        form.add("pg_sig", signature);
        return form;
    }

    /** Reimplements FreedomPaySignature.compute (package-private in payment-provider) against known test inputs. */
    private static String computeSignature(String scriptName, Map<String, String> fields, String secretKey) {
        SortedMap<String, String> sorted = new TreeMap<>(fields);
        StringBuilder toSign = new StringBuilder(scriptName);
        for (String value : sorted.values()) {
            toSign.append(';').append(value == null ? "" : value);
        }
        toSign.append(';').append(secretKey);
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] hash = digest.digest(toSign.toString().getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
