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
        ResponseEntity<Map> checkBefore = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(checkBefore.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Charge — mock provider always succeeds.
        ResponseEntity<Map> payResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(payResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(payResponse.getBody().get("status")).isEqualTo("SUCCEEDED");
        assertThat(payResponse.getBody().get("amount")).isEqualTo(35.00);
        UUID paymentId = UUID.fromString(payResponse.getBody().get("id").toString());

        // A second payment attempt on the same booking is rejected.
        ResponseEntity<Map> duplicatePay = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
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

        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);

        ResponseEntity<Map> cancelResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(cancelResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // BookingCancelledPaymentListener (AFTER_COMMIT, REQUIRES_NEW) already
        // ran synchronously by the time the cancel response comes back.
        ResponseEntity<Map> paymentAfterCancel = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(paymentAfterCancel.getBody().get("status")).isEqualTo("REFUNDED");
    }

    @Test
    void aFailedChargeCanBeRetriedReusingTheSamePaymentIdAsTheIdempotencyKey() {
        BookingForPayment bfp = createBookingForPayment("retry-", new BigDecimal("22.00"));
        UUID bookingId = bfp.bookingId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken()));

        failureController.failNextCharge = true;
        ResponseEntity<Map> firstAttempt = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, customerAuth, Map.class);
        assertThat(firstAttempt.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(firstAttempt.getBody().get("status")).isEqualTo("FAILED");
        UUID paymentId = UUID.fromString(firstAttempt.getBody().get("id").toString());

        ResponseEntity<Map> retry = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, customerAuth, Map.class);
        assertThat(retry.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(retry.getBody().get("status")).isEqualTo("SUCCEEDED");
        // Same payment id across the failed attempt and the successful retry —
        // this IS the idempotency key a real provider would rely on.
        assertThat(retry.getBody().get("id")).isEqualTo(paymentId.toString());
    }

    @Test
    void aProviderExceptionDuringChargeMarksThePaymentFailedInsteadOfCrashing() {
        BookingForPayment bfp = createBookingForPayment("outage-", new BigDecimal("18.00"));
        UUID bookingId = bfp.bookingId();

        failureController.failNextCharge = true;
        failureController.throwOnNextCharge = true;
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().get("status")).isEqualTo("FAILED");
    }

    @Test
    void aFailedRefundIsRecordedOnThePaymentInsteadOfOnlyBeingLogged() {
        BookingForPayment bfp = createBookingForPayment("refund-outage-", new BigDecimal("22.00"));
        UUID bookingId = bfp.bookingId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken()));
        UUID paymentId = UUID.fromString(restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, customerAuth, Map.class).getBody().get("id").toString());
        var admin = registerPlatformAdmin("refund-outage-admin-" + UUID.randomUUID());

        failureController.failNextRefund = true;
        ResponseEntity<Map> refundResponse = refundAs(paymentId, admin);
        assertThat(refundResponse.getStatusCode()).isEqualTo(HttpStatus.BAD_GATEWAY);

        // The failure survived the exception — not rolled back with it (see
        // PaymentsService.refundPayment's noRollbackFor) — and status moves
        // to REFUND_FAILED, not REFUNDED: the money was never actually
        // returned, so the payment can't claim it was.
        ResponseEntity<Map> check = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.GET, customerAuth, Map.class);
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
        BookingForPayment bfp = createBookingForPayment("refund-authz-", new BigDecimal("50.00"));
        UUID bookingId = bfp.bookingId();
        Registered customer = TestAuth.registerCustomer(restTemplate, "refund-authz-cust-" + runId
                + "@example.com");
        UUID paymentId = UUID.fromString(restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken())),
                Map.class).getBody().get("id").toString());

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

    /**
     * Proves the fix for the charge endpoint's missing authorization: only the
     * booking's own customer or its provider's own owner may charge it (mirrors
     * BookingApiTests.gettingABookingRequiresBeingItsCustomerOrItsProvidersOwner).
     * Each "allowed" outcome needs its own unpaid booking, since a successful
     * charge leaves the booking unavailable for a second one (CONFLICT, not the
     * authorization outcome this test is about).
     */
    @Test
    void chargingABookingRequiresBeingItsCustomerOrItsProvidersOwner() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "chargeauthz-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "chargeauthz-other-owner-" + runId
                + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "chargeauthz-other-cust-" + runId
                + "@example.com");

        UUID providerId = createProvider(owner, "Charge Authz Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Charge Authz Service", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);

        // No token at all -> 401.
        Registered unauthBookingCustomer = TestAuth.registerCustomer(restTemplate, "chargeauthz-unauth-cust-"
                + runId + "@example.com");
        UUID unauthSlotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID unauthBookingId = createBooking(unauthBookingCustomer, serviceId, unauthSlotId,
                new BigDecimal("20.00"));
        ResponseEntity<Map> unauthenticated = restTemplate.postForEntity(
                "/api/v1/bookings/" + unauthBookingId + "/payments", null, Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The booking's own customer can pay for it.
        Registered customer1 = TestAuth.registerCustomer(restTemplate, "chargeauthz-cust1-" + runId
                + "@example.com");
        UUID slot1 = createSlot(owner, providerId, start.plus(1, ChronoUnit.HOURS),
                start.plus(90, ChronoUnit.MINUTES));
        UUID booking1 = createBooking(customer1, serviceId, slot1, new BigDecimal("20.00"));
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/bookings/" + booking1 + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer1.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // The provider's own owner can pay for it too.
        Registered customer2 = TestAuth.registerCustomer(restTemplate, "chargeauthz-cust2-" + runId
                + "@example.com");
        UUID slot2 = createSlot(owner, providerId, start.plus(2, ChronoUnit.HOURS),
                start.plus(150, ChronoUnit.MINUTES));
        UUID booking2 = createBooking(customer2, serviceId, slot2, new BigDecimal("20.00"));
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/bookings/" + booking2 + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // A different customer cannot.
        Registered customer3 = TestAuth.registerCustomer(restTemplate, "chargeauthz-cust3-" + runId
                + "@example.com");
        UUID slot3 = createSlot(owner, providerId, start.plus(3, ChronoUnit.HOURS),
                start.plus(210, ChronoUnit.MINUTES));
        UUID booking3 = createBooking(customer3, serviceId, slot3, new BigDecimal("20.00"));
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/bookings/" + booking3 + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different provider's owner cannot either.
        Registered customer4 = TestAuth.registerCustomer(restTemplate, "chargeauthz-cust4-" + runId
                + "@example.com");
        UUID slot4 = createSlot(owner, providerId, start.plus(4, ChronoUnit.HOURS),
                start.plus(270, ChronoUnit.MINUTES));
        UUID booking4 = createBooking(customer4, serviceId, slot4, new BigDecimal("20.00"));
        ResponseEntity<Map> asOtherOwner = restTemplate.exchange("/api/v1/bookings/" + booking4 + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(asOtherOwner.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    /**
     * Proves the fix for the "read a booking's payment" endpoint's missing
     * authorization: same customer-or-provider-owner rule as the charge
     * endpoint above. Reads don't mutate state, so a single paid booking is
     * reused across all five scenarios.
     */
    @Test
    void gettingAPaymentForABookingRequiresBeingItsCustomerOrItsProvidersOwner() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "getpay-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "getpay-other-owner-" + runId
                + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "getpay-customer-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "getpay-other-cust-" + runId
                + "@example.com");

        UUID providerId = createProvider(owner, "Get Pay Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Get Pay Service", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, serviceId, slotId, new BigDecimal("20.00"));
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity(
                "/api/v1/bookings/" + bookingId + "/payments", Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The booking's own customer can read its payment.
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The provider's own owner can read it too.
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.OK);

        // A different customer cannot.
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different provider's owner cannot either.
        ResponseEntity<Map> asOtherOwner = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(asOtherOwner.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    /**
     * Proves the fix for P1-2: createPayment now checks the booking's own
     * status, not just authorization — an otherwise-authorized caller still
     * can't charge a booking once it has left PENDING_PAYMENT (already paid,
     * cancelled, or completed). Also proves no payment is ever created for a
     * rejected attempt: CANCELLED never had one to begin with (still 404
     * afterwards), and CONFIRMED/COMPLETED keep the exact payment from their
     * original successful charge — same id, still SUCCEEDED — rather than a
     * duplicate or an overwrite.
     */
    @Test
    void creatingAPaymentRequiresTheBookingToBeAwaitingPayment() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "statusguard-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Status Guard Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Status Guard Service", new BigDecimal("15.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);

        // 1. PENDING_PAYMENT -> allowed for an authorized caller.
        Registered pendingCustomer = TestAuth.registerCustomer(restTemplate, "statusguard-pending-" + runId
                + "@example.com");
        UUID pendingSlot = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID pendingBookingId = createBooking(pendingCustomer, serviceId, pendingSlot, new BigDecimal("15.00"));
        var pendingAuth = new HttpEntity<>(null, TestAuth.authHeaders(pendingCustomer.accessToken()));
        ResponseEntity<Map> pendingPay = restTemplate.exchange("/api/v1/bookings/" + pendingBookingId
                + "/payments", HttpMethod.POST, pendingAuth, Map.class);
        assertThat(pendingPay.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(pendingPay.getBody().get("status")).isEqualTo("SUCCEEDED");

        // 2. CONFIRMED (that same booking, now paid) -> rejected; the
        // existing payment is left exactly as it was.
        ResponseEntity<Map> confirmedPay = restTemplate.exchange("/api/v1/bookings/" + pendingBookingId
                + "/payments", HttpMethod.POST, pendingAuth, Map.class);
        assertThat(confirmedPay.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        ResponseEntity<Map> confirmedPayment = restTemplate.exchange("/api/v1/bookings/" + pendingBookingId
                + "/payments", HttpMethod.GET, pendingAuth, Map.class);
        assertThat(confirmedPayment.getBody().get("id")).isEqualTo(pendingPay.getBody().get("id"));
        assertThat(confirmedPayment.getBody().get("status")).isEqualTo("SUCCEEDED");

        // 3. CANCELLED (never paid) -> rejected; no payment is ever created.
        Registered cancelledCustomer = TestAuth.registerCustomer(restTemplate, "statusguard-cancelled-" + runId
                + "@example.com");
        UUID cancelledSlot = createSlot(owner, providerId, start.plus(1, ChronoUnit.HOURS),
                start.plus(90, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(cancelledCustomer, serviceId, cancelledSlot,
                new BigDecimal("15.00"));
        var cancelledAuth = new HttpEntity<>(null, TestAuth.authHeaders(cancelledCustomer.accessToken()));
        ResponseEntity<Map> cancelResponse = restTemplate.exchange("/api/v1/bookings/" + cancelledBookingId
                + "/cancel", HttpMethod.POST, cancelledAuth, Map.class);
        assertThat(cancelResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        ResponseEntity<Map> cancelledPay = restTemplate.exchange("/api/v1/bookings/" + cancelledBookingId
                + "/payments", HttpMethod.POST, cancelledAuth, Map.class);
        assertThat(cancelledPay.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        ResponseEntity<Map> cancelledPaymentCheck = restTemplate.exchange("/api/v1/bookings/" + cancelledBookingId
                + "/payments", HttpMethod.GET, cancelledAuth, Map.class);
        assertThat(cancelledPaymentCheck.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // 4. COMPLETED -> rejected; the original successful payment is
        // left exactly as it was.
        Registered completedCustomer = TestAuth.registerCustomer(restTemplate, "statusguard-completed-" + runId
                + "@example.com");
        UUID completedSlot = createSlot(owner, providerId, start.plus(2, ChronoUnit.HOURS),
                start.plus(150, ChronoUnit.MINUTES));
        UUID completedBookingId = createBooking(completedCustomer, serviceId, completedSlot,
                new BigDecimal("15.00"));
        var completedAuth = new HttpEntity<>(null, TestAuth.authHeaders(completedCustomer.accessToken()));
        ResponseEntity<Map> completedFirstPay = restTemplate.exchange("/api/v1/bookings/" + completedBookingId
                + "/payments", HttpMethod.POST, completedAuth, Map.class);
        assertThat(completedFirstPay.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        ResponseEntity<Map> completeResponse = restTemplate.exchange("/api/v1/bookings/" + completedBookingId
                + "/complete", HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(completeResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        ResponseEntity<Map> completedPay = restTemplate.exchange("/api/v1/bookings/" + completedBookingId
                + "/payments", HttpMethod.POST, completedAuth, Map.class);
        assertThat(completedPay.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        ResponseEntity<Map> completedPaymentCheck = restTemplate.exchange("/api/v1/bookings/" + completedBookingId
                + "/payments", HttpMethod.GET, completedAuth, Map.class);
        assertThat(completedPaymentCheck.getBody().get("id")).isEqualTo(completedFirstPay.getBody().get("id"));
        assertThat(completedPaymentCheck.getBody().get("status")).isEqualTo("SUCCEEDED");
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

    private record BookingForPayment(UUID bookingId, Registered customer, Registered owner) {
    }

    private BookingForPayment createBookingForPayment(String prefix, BigDecimal price) {
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
        return new BookingForPayment(UUID.fromString(booking.get("id").toString()), customer, owner);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
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
