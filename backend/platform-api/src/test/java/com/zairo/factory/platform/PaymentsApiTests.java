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
 * Against a real Postgres (Testcontainers): create a booking, pay for it
 * (through the mock PaymentProvider — always succeeds), verify it shows up,
 * reject a second payment attempt, then refund and verify the refund
 * guardrail (can't refund twice).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class, TestNotifications.class})
class PaymentsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestPayments.FailureController failureController;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void paysForABookingThenRefundsIt() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "pay-customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "pay-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Payment Test Salon " + runId, "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest("Pay Service", 30, new BigDecimal("35.00"), "USD");
        ResponseEntity<Map> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        UUID serviceId = UUID.fromString(serviceResponse.getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("35.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());

        // No payment yet.
        ResponseEntity<Map> checkBefore = restTemplate.getForEntity("/api/v1/bookings/" + bookingId + "/payments",
                Map.class);
        assertThat(checkBefore.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Charge — mock provider always succeeds.
        ResponseEntity<Map> payResponse = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments",
                null, Map.class);
        assertThat(payResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(payResponse.getBody().get("status")).isEqualTo("SUCCEEDED");
        assertThat(payResponse.getBody().get("amount")).isEqualTo(35.00);
        UUID paymentId = UUID.fromString(payResponse.getBody().get("id").toString());

        // A second payment attempt on the same booking is rejected.
        ResponseEntity<Map> duplicatePay = restTemplate.postForEntity(
                "/api/v1/bookings/" + bookingId + "/payments", null, Map.class);
        assertThat(duplicatePay.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Refund is PLATFORM_ADMIN-only — see PaymentsController.refund.
        var admin = registerPlatformAdmin("pay-refund-admin-" + runId);

        // Refund succeeds.
        ResponseEntity<Map> refundResponse = refundAs(paymentId, admin);
        assertThat(refundResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(refundResponse.getBody().get("status")).isEqualTo("REFUNDED");
        // Amount/currency still come from the payment itself — refund takes
        // no request body, so there is nothing for a caller to override.
        assertThat(refundResponse.getBody().get("amount")).isEqualTo(35.00);
        assertThat(refundResponse.getBody().get("currency")).isEqualTo("USD");

        // The customer is notified once the refund actually succeeds.
        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.subject()).isEqualTo("Refund processed");
            assertThat(email.body()).contains(bookingId.toString());
        });

        // A second refund attempt is rejected — already refunded, not SUCCEEDED.
        ResponseEntity<Map> duplicateRefund = refundAs(paymentId, admin);
        assertThat(duplicateRefund.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void cancellingAPaidBookingAutomaticallyRefundsIt() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "refund-customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "refund-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Refund Test Salon " + runId, "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest("Refund Service", 30, new BigDecimal("40.00"), "USD");
        ResponseEntity<Map> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        UUID serviceId = UUID.fromString(serviceResponse.getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("40.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());

        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments", null, Map.class);

        ResponseEntity<Map> cancelResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(cancelResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // BookingCancelledPaymentListener (AFTER_COMMIT, REQUIRES_NEW) already
        // ran synchronously by the time the cancel response comes back.
        ResponseEntity<Map> paymentAfterCancel = restTemplate.getForEntity(
                "/api/v1/bookings/" + bookingId + "/payments", Map.class);
        assertThat(paymentAfterCancel.getBody().get("status")).isEqualTo("REFUNDED");
    }

    @Test
    void aFailedChargeCanBeRetriedReusingTheSamePaymentIdAsTheIdempotencyKey() {
        UUID bookingId = createBookingForPayment("retry-", new BigDecimal("22.00"));

        failureController.failNextCharge = true;
        ResponseEntity<Map> firstAttempt = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments",
                null, Map.class);
        assertThat(firstAttempt.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(firstAttempt.getBody().get("status")).isEqualTo("FAILED");
        UUID paymentId = UUID.fromString(firstAttempt.getBody().get("id").toString());

        ResponseEntity<Map> retry = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments", null,
                Map.class);
        assertThat(retry.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(retry.getBody().get("status")).isEqualTo("SUCCEEDED");
        // Same payment id across the failed attempt and the successful retry —
        // this IS the idempotency key a real provider would rely on.
        assertThat(retry.getBody().get("id")).isEqualTo(paymentId.toString());
    }

    @Test
    void aProviderExceptionDuringChargeMarksThePaymentFailedInsteadOfCrashing() {
        UUID bookingId = createBookingForPayment("outage-", new BigDecimal("18.00"));

        failureController.failNextCharge = true;
        failureController.throwOnNextCharge = true;
        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments",
                null, Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().get("status")).isEqualTo("FAILED");
    }

    @Test
    void aFailedRefundIsRecordedOnThePaymentInsteadOfOnlyBeingLogged() {
        UUID bookingId = createBookingForPayment("refund-outage-", new BigDecimal("22.00"));
        UUID paymentId = UUID.fromString(restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments",
                null, Map.class).getBody().get("id").toString());
        var admin = registerPlatformAdmin("refund-outage-admin-" + UUID.randomUUID());

        failureController.failNextRefund = true;
        ResponseEntity<Map> refundResponse = refundAs(paymentId, admin);
        assertThat(refundResponse.getStatusCode()).isEqualTo(HttpStatus.BAD_GATEWAY);

        // The failure survived the exception — not rolled back with it (see
        // PaymentsService.refundPayment's noRollbackFor) — and status moves
        // to REFUND_FAILED, not REFUNDED: the money was never actually
        // returned, so the payment can't claim it was.
        ResponseEntity<Map> check = restTemplate.getForEntity("/api/v1/bookings/" + bookingId + "/payments",
                Map.class);
        assertThat(check.getBody().get("status")).isEqualTo("REFUND_FAILED");
        assertThat(check.getBody().get("refundFailureReason")).isEqualTo("simulated refund outage");
        assertThat(check.getBody().get("refundAttempts")).isEqualTo(1);

        // Retrying (the mock provider succeeds by default now that the
        // one-shot failure flag has been consumed) clears the failure and
        // actually refunds it.
        ResponseEntity<Map> retry = refundAs(paymentId, admin);
        assertThat(retry.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(retry.getBody().get("status")).isEqualTo("REFUNDED");
        assertThat(retry.getBody().get("refundFailureReason")).isNull();
    }

    /**
     * Proves the fix for the refund endpoint's missing authorization:
     * PLATFORM_ADMIN-only (mirrors PaymentAdminApiTests' own coverage of the
     * failed-refund visibility endpoint, the read-side counterpart of this
     * same admin surface).
     */
    @Test
    void refundingAPaymentRequiresPlatformAdminAndRejectsEveryoneElse() {
        String runId = UUID.randomUUID().toString();
        UUID bookingId = createBookingForPayment("refund-authz-", new BigDecimal("50.00"));
        Registered customer = TestAuth.registerCustomer(restTemplate, "refund-authz-cust-" + runId
                + "@example.com");
        UUID paymentId = UUID.fromString(restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments",
                null, Map.class).getBody().get("id").toString());

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.postForEntity("/api/v1/payments/" + paymentId
                + "/refund", null, Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // A regular (non-platform) bearer token is not a platform access
        // token at all — same 401, not 403, as the fully anonymous case.
        // This is what "can't refund someone else's payment" collapses to
        // under a PLATFORM_ADMIN-only design: no customer or provider token,
        // including the payment's own customer's, is ever a valid platform
        // token, so none of them can reach the role check to begin with —
        // see PlatformCurrentAdmin.requireAnyRole's own doc comment.
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/payments/" + paymentId + "/refund",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // A valid platform token with an insufficient role -> 403. PLATFORM_SUPPORT
        // is read-only across the whole Control Center (see PlatformRole's own
        // doc comment) — it can list failed refunds but not retry one.
        var support = registerPlatformAdmin("refund-authz-support-" + runId, PlatformRole.PLATFORM_SUPPORT);
        ResponseEntity<Map> asSupport = refundAs(paymentId, support);
        assertThat(asSupport.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // PLATFORM_ADMIN succeeds.
        var admin = registerPlatformAdmin("refund-authz-admin-" + runId);
        ResponseEntity<Map> asAdmin = refundAs(paymentId, admin);
        assertThat(asAdmin.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(asAdmin.getBody().get("status")).isEqualTo("REFUNDED");
        // Amount/currency come from the payment itself, unaffected by who called it.
        assertThat(asAdmin.getBody().get("amount")).isEqualTo(50.00);
        assertThat(asAdmin.getBody().get("currency")).isEqualTo("USD");
    }

    private TestPlatformAuth.Registered registerPlatformAdmin(String emailPrefix) {
        return registerPlatformAdmin(emailPrefix, PlatformRole.PLATFORM_ADMIN);
    }

    private TestPlatformAuth.Registered registerPlatformAdmin(String emailPrefix, PlatformRole role) {
        return TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                emailPrefix + "@factory.internal", role);
    }

    private ResponseEntity<Map> refundAs(UUID paymentId, TestPlatformAuth.Registered admin) {
        return restTemplate.exchange("/api/v1/payments/" + paymentId + "/refund", HttpMethod.POST,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
    }

    private UUID createBookingForPayment(String prefix, BigDecimal price) {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, prefix + "customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, prefix + "owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), prefix + "Salon " + runId, "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest(prefix + "Service", 30, price, "USD");
        ResponseEntity<Map> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        UUID serviceId = UUID.fromString(serviceResponse.getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, price);
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        return UUID.fromString(booking.get("id").toString());
    }
}
