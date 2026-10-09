package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Against a real Postgres (Testcontainers): the marketplace commission
 * split (see ADR-0007) end to end — pay a booking, complete it, verify the
 * business's payable settlement appears with the correct split, and that
 * both the payout-visibility and refund-vs-payout guardrails hold.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class, TestNotifications.class})
class BusinessSettlementApiTests {

    private static final String BEAUTY_CATEGORY_ID = "a1111111-1111-4111-8111-111111111111";

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void completingABookingCreatesAPayableBusinessPayoutWithNoCommissionByDefault() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "settle-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Settlement Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Settlement Service", new BigDecimal("100.00"));

        Registered customer = TestAuth.registerCustomer(restTemplate, "settle-cust-" + runId + "@example.com");
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, serviceId, slotId, new BigDecimal("100.00"));

        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken()));
        ResponseEntity<Map> payResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, customerAuth, Map.class);
        assertThat(payResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        // The platform-wide default is 0% until a PLATFORM_ADMIN sets one.
        assertThat(payResponse.getBody().get("businessAmount")).isEqualTo(100.00);
        assertThat(payResponse.getBody().get("platformFee")).isEqualTo(0.00);

        // No payout yet — the booking is only CONFIRMED, not COMPLETED.
        ResponseEntity<List> beforeCompletion = restTemplate.exchange("/api/v1/providers/" + providerId + "/payouts",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(beforeCompletion.getBody()).isEmpty();

        var ownerAuth = new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken()));
        ResponseEntity<Map> completeResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete",
                HttpMethod.POST, ownerAuth, Map.class);
        assertThat(completeResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<List> afterCompletion = restTemplate.exchange("/api/v1/providers/" + providerId + "/payouts",
                HttpMethod.GET, ownerAuth, List.class);
        assertThat(afterCompletion.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(afterCompletion.getBody()).hasSize(1);
        Map<?, ?> payout = (Map<?, ?>) afterCompletion.getBody().get(0);
        assertThat(payout.get("bookingId")).isEqualTo(bookingId.toString());
        assertThat(payout.get("amount")).isEqualTo(100.00);
        assertThat(payout.get("status")).isEqualTo("PAYABLE");
    }

    @Test
    void aCategoryCommissionSetByPlatformAdminAppliesToThatCategorysBookingsAndCanBeCleared() {
        var admin = registerPlatformAdmin("settle-commission-admin-" + UUID.randomUUID());
        var adminAuth = TestPlatformAuth.authHeaders(admin.accessToken());

        // A non-admin cannot change the commission.
        Registered owner = TestAuth.registerOwner(restTemplate, "settle-commission-owner-" + UUID.randomUUID()
                + "@example.com");
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/platform/commission/categories/"
                + BEAUTY_CATEGORY_ID, HttpMethod.PUT, new HttpEntity<>(Map.of("ratePercent", 10),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isIn(HttpStatus.UNAUTHORIZED, HttpStatus.FORBIDDEN);

        // An out-of-range percent is rejected.
        ResponseEntity<Map> tooHigh = restTemplate.exchange("/api/v1/platform/commission/default", HttpMethod.PUT,
                new HttpEntity<>(Map.of("ratePercent", 101), adminAuth), Map.class);
        assertThat(tooHigh.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        try {
            ResponseEntity<Map> set = restTemplate.exchange("/api/v1/platform/commission/categories/"
                    + BEAUTY_CATEGORY_ID, HttpMethod.PUT, new HttpEntity<>(Map.of("ratePercent", 10), adminAuth),
                    Map.class);
            assertThat(set.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(commissionOf(set.getBody(), BEAUTY_CATEGORY_ID).get("effectivePercent")).isEqualTo(10.0);

            // 100.00 at the beauty category's 10% -> 90.00 business / 10.00 fee.
            BookingContext withCommission = payAndCompleteABooking("catcomm-", new BigDecimal("100.00"));
            Map<?, ?> payout = (Map<?, ?>) restTemplate.exchange("/api/v1/providers/" + withCommission.providerId()
                    + "/payouts", HttpMethod.GET, new HttpEntity<>(null,
                            TestAuth.authHeaders(withCommission.owner().accessToken())), List.class).getBody().get(0);
            assertThat(payout.get("amount")).isEqualTo(90.00);

            ResponseEntity<Map> cleared = restTemplate.exchange("/api/v1/platform/commission/categories/"
                    + BEAUTY_CATEGORY_ID, HttpMethod.DELETE, new HttpEntity<>(null, adminAuth), Map.class);
            assertThat(cleared.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(commissionOf(cleared.getBody(), BEAUTY_CATEGORY_ID).get("overridePercent")).isNull();

            // Back on the 0% default: the earlier payment keeps its snapshot, a new one pays no commission.
            BookingContext afterClear = payAndCompleteABooking("catcomm-clear-", new BigDecimal("100.00"));
            Map<?, ?> payoutAfter = (Map<?, ?>) restTemplate.exchange("/api/v1/providers/" + afterClear.providerId()
                    + "/payouts", HttpMethod.GET, new HttpEntity<>(null,
                            TestAuth.authHeaders(afterClear.owner().accessToken())), List.class).getBody().get(0);
            assertThat(payoutAfter.get("amount")).isEqualTo(100.00);
        } finally {
            restTemplate.exchange("/api/v1/platform/commission/categories/" + BEAUTY_CATEGORY_ID, HttpMethod.DELETE,
                    new HttpEntity<>(null, adminAuth), Map.class);
        }
    }

    private static Map<?, ?> commissionOf(Map<?, ?> settings, String categoryId) {
        return ((List<?>) settings.get("categories")).stream().map(c -> (Map<?, ?>) c)
                .filter(c -> categoryId.equals(c.get("categoryId"))).findFirst().orElseThrow();
    }

    @Test
    void aDifferentProvidersOwnerCannotSeeThisProvidersPayouts() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "settle-authz-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "settle-authz-other-" + runId
                + "@example.com");
        UUID providerId = createProvider(owner, "Settlement Authz Salon " + runId);

        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/providers/" + providerId + "/payouts",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void platformAdminCanMarkAPayoutPaidAndASecondAttemptIsRejectedAsTerminal() {
        BookingContext ctx = payAndCompleteABooking("markpaid-", new BigDecimal("50.00"));
        var admin = registerPlatformAdmin("settle-markpaid-admin-" + UUID.randomUUID());
        UUID payoutId = onlyPayoutId(ctx.providerId(), ctx.owner());

        ResponseEntity<Map> markPaid = restTemplate.exchange("/api/v1/platform/payouts/" + payoutId + "/mark-paid",
                HttpMethod.POST, new HttpEntity<>(Map.of("providerReference", "manual-transfer-1"),
                        TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(markPaid.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(markPaid.getBody().get("status")).isEqualTo("PAID");
        assertThat(markPaid.getBody().get("providerReference")).isEqualTo("manual-transfer-1");

        ResponseEntity<Map> secondAttempt = restTemplate.exchange("/api/v1/platform/payouts/" + payoutId
                + "/mark-paid", HttpMethod.POST, new HttpEntity<>(null,
                        TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(secondAttempt.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void refundingAPaymentIsBlockedOnceItsBusinessPayoutHasBeenPaid() {
        BookingContext ctx = payAndCompleteABooking("refundblock-", new BigDecimal("40.00"));
        var admin = registerPlatformAdmin("settle-refundblock-admin-" + UUID.randomUUID());
        UUID payoutId = onlyPayoutId(ctx.providerId(), ctx.owner());

        restTemplate.exchange("/api/v1/platform/payouts/" + payoutId + "/mark-paid", HttpMethod.POST,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);

        ResponseEntity<Map> refundAttempt = restTemplate.exchange("/api/v1/payments/" + ctx.paymentId() + "/refund",
                HttpMethod.POST, new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())),
                Map.class);
        assertThat(refundAttempt.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void reconciliationMatchesForASucceededPaymentAgainstTheConfiguredProvider() {
        BookingContext ctx = payAndCompleteABooking("reconcile-", new BigDecimal("60.00"));
        var admin = registerPlatformAdmin("settle-reconcile-admin-" + UUID.randomUUID());

        ResponseEntity<Map> reconcile = restTemplate.exchange("/api/v1/platform/payments/" + ctx.paymentId()
                + "/reconcile", HttpMethod.POST, new HttpEntity<>(null,
                        TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(reconcile.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reconcile.getBody().get("outcome")).isEqualTo("MATCH");
        assertThat(reconcile.getBody().get("localStatus")).isEqualTo("SUCCEEDED");
        assertThat(reconcile.getBody().get("providerStatus")).isEqualTo("SUCCEEDED");
    }

    private record BookingContext(UUID bookingId, UUID paymentId, UUID providerId, Registered owner) {
    }

    private BookingContext payAndCompleteABooking(String prefix, BigDecimal price) {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, prefix + "owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, prefix + "Salon " + runId);
        UUID serviceId = createService(owner, providerId, prefix + "Service", price);

        Registered customer = TestAuth.registerCustomer(restTemplate, prefix + "cust-" + runId + "@example.com");
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, serviceId, slotId, price);

        ResponseEntity<Map> payResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        UUID paymentId = UUID.fromString(payResponse.getBody().get("id").toString());

        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);

        return new BookingContext(bookingId, paymentId, providerId, owner);
    }

    private UUID onlyPayoutId(UUID providerId, Registered owner) {
        ResponseEntity<List> payouts = restTemplate.exchange("/api/v1/providers/" + providerId + "/payouts",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(payouts.getBody()).hasSize(1);
        Map<?, ?> payout = (Map<?, ?>) payouts.getBody().get(0);
        return UUID.fromString(payout.get("id").toString());
    }

    private TestPlatformAuth.Registered registerPlatformAdmin(String emailPrefix) {
        return TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                emailPrefix + "@factory.internal", PlatformRole.PLATFORM_ADMIN);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString(response.getBody().get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        return providerId;
    }

    private UUID createService(Registered owner, UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createSlot(Registered owner, UUID providerId, Instant startsAt, Instant endsAt) {
        var request = new CreateAvailabilitySlotRequest(startsAt, endsAt);
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createBooking(Registered customer, UUID serviceId, UUID slotId, BigDecimal price) {
        var request = new CreateBookingRequest(customer.userId(), serviceId, slotId, price);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
