package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import java.math.BigDecimal;
import java.time.Duration;
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
 * The durable refund-outbox flow (see {@code payments.PaymentRefundRequest}
 * and {@code docs/adr/0006-payment-provider-freedompay.md}'s "Durable Refund
 * Outbox" section) against a real Postgres (Testcontainers). Two scenarios
 * are deliberately NOT covered here, by design, not oversight:
 *
 * <ul>
 *   <li><b>Concurrent-worker exclusivity</b> — {@code
 *   PaymentRefundRequestRepository#lockById}'s {@code PESSIMISTIC_WRITE}
 *   lock reuses the exact same mechanism {@link LoyaltyApiTests}'s
 *   {@code onlyOneOfTwoConcurrentRedemptionsForANearlyExhaustedBalanceSucceeds}
 *   already proves correct for a different entity; there is no public HTTP
 *   endpoint that triggers a claim directly (the worker is internal), so
 *   this can't be exercised the same way without duplicating that proof
 *   against internals a different package can't call.</li>
 *   <li><b>Restart recovery from a stale PROCESSING row</b> — {@code
 *   PaymentRefundRequest#isClaimable}'s exact 5-minute-threshold behavior is
 *   covered by {@code PaymentRefundRequestTest} (plain unit test, no
 *   Testcontainers); reproducing it here would mean either a real 5-minute
 *   wait or reaching into the same package-private state this suite can't
 *   see from {@code platform-api}.</li>
 * </ul>
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class, TestNotifications.class, TestClock.class})
class PaymentRefundOutboxApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestPayments.FailureController failureController;

    @Autowired
    private MutableClock clock;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void cancellingAPaidBookingCreatesADurableRefundRequestThatResolvesInTheHappyPath() {
        BookingForPayment bfp = createBookingForPayment("outbox-happy-", new BigDecimal("35.00"));
        UUID bookingId = bfp.bookingId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken()));
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST, customerAuth,
                Map.class);

        ResponseEntity<Map> cancelResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, customerAuth, Map.class);
        assertThat(cancelResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The eager AFTER_COMMIT nudge (PaymentRefundOutboxProcessor#onRefundRequestReady)
        // runs synchronously within the same request against the mock
        // provider (always succeeds, no real network latency) — the whole
        // claim -> provider call -> apply-success chain has already
        // completed by the time the cancel response comes back, same
        // observable timing the old best-effort listener had.
        ResponseEntity<Map> paymentAfterCancel = getPayment(bookingId, bfp.customer());
        assertThat(paymentAfterCancel.getBody().get("status")).isEqualTo("REFUNDED");

        var admin = registerPlatformAdmin("outbox-happy-admin-" + UUID.randomUUID());
        List<Map<String, Object>> succeeded = listRefundRequests("SUCCEEDED", admin);
        assertThat(succeeded).anySatisfy(row -> {
            assertThat(row.get("bookingId")).isEqualTo(bookingId.toString());
            assertThat(row.get("status")).isEqualTo("SUCCEEDED");
            assertThat(row.get("attempts")).isEqualTo(0);
        });
    }

    @Test
    void cancellingABookingThatWasNeverChargedCreatesNoRefundRequest() {
        BookingForPayment bfp = createBookingForPayment("outbox-unpaid-", new BigDecimal("18.00"));
        UUID bookingId = bfp.bookingId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken()));

        // Never charged — cancel straight from PENDING_PAYMENT.
        ResponseEntity<Map> cancelResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, customerAuth, Map.class);
        assertThat(cancelResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Nothing to refund — no payment ever existed for this booking, so
        // there is nothing BookingCancelledPaymentListener's filter on
        // PaymentStatus.SUCCEEDED could have acted on.
        ResponseEntity<Map> paymentCheck = getPayment(bookingId, bfp.customer());
        assertThat(paymentCheck.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void aTransientRefundFailureRetriesWithBackoffAndEventuallySucceeds() {
        BookingForPayment bfp = createBookingForPayment("outbox-retry-", new BigDecimal("27.00"));
        UUID bookingId = bfp.bookingId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken()));
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST, customerAuth,
                Map.class);

        // The first (eager, synchronous) attempt fails; the very next one
        // (after backoff) succeeds.
        failureController.failRefundTimes.set(1);
        Instant cancelledAt = clock.instant();
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel", HttpMethod.POST, customerAuth,
                Map.class);

        // Not yet resolved — the eager attempt failed, so the payment sits
        // REFUND_PENDING (not REFUNDED, not REFUND_FAILED) while the outbox
        // row waits out its backoff.
        assertThat(getPayment(bookingId, bfp.customer()).getBody().get("status")).isEqualTo("REFUND_PENDING");

        // Clear the 30s backoff window (see PaymentRefundRequest's exponential
        // backoff) so the next real scheduled sweep (every 15s of actual
        // wall-clock time — @Scheduled doesn't know about this test's
        // MutableClock) picks the row back up as due.
        clock.advanceTo(cancelledAt.plus(Duration.ofMinutes(1)));

        Map<?, ?> finalPayment = awaitPaymentStatus(bookingId, bfp.customer(), "REFUNDED");
        assertThat(finalPayment.get("status")).isEqualTo("REFUNDED");

        var admin = registerPlatformAdmin("outbox-retry-admin-" + UUID.randomUUID());
        List<Map<String, Object>> succeeded = listRefundRequests("SUCCEEDED", admin);
        assertThat(succeeded).anySatisfy(row -> {
            assertThat(row.get("bookingId")).isEqualTo(bookingId.toString());
            assertThat(row.get("attempts")).isEqualTo(1); // one recorded failure before the successful retry
        });
    }

    @Test
    void cancellingAnAlreadyCancelledBookingIsRejected_soNoDuplicateRefundRequestCanEverBeCreated() {
        BookingForPayment bfp = createBookingForPayment("outbox-dup-", new BigDecimal("30.00"));
        UUID bookingId = bfp.bookingId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(bfp.customer().accessToken()));
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST, customerAuth,
                Map.class);

        ResponseEntity<Map> firstCancel = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, customerAuth, Map.class);
        assertThat(firstCancel.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getPayment(bookingId, bfp.customer()).getBody().get("status")).isEqualTo("REFUNDED");

        // BookingService#cancelBooking's own status guard rejects a second
        // cancellation of an already-CANCELLED booking — BookingCancelledEvent
        // (and so PaymentRefundRequest creation) can never fire twice for the
        // same booking through the public API, which is this codebase's real
        // idempotency guarantee here (payment_id unique is the defense-in-depth
        // backstop — see BookingCancelledPaymentListener's own doc comment).
        ResponseEntity<Map> secondCancel = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, customerAuth, Map.class);
        assertThat(secondCancel.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Still just the one, still REFUNDED — not double-refunded, not reset.
        assertThat(getPayment(bookingId, bfp.customer()).getBody().get("status")).isEqualTo("REFUNDED");
    }

    private Map<?, ?> awaitPaymentStatus(UUID bookingId, Registered customer, String expectedStatus) {
        Instant deadline = Instant.now().plusSeconds(25);
        Map<?, ?> last = null;
        while (Instant.now().isBefore(deadline)) {
            last = getPayment(bookingId, customer).getBody();
            if (expectedStatus.equals(last.get("status"))) {
                return last;
            }
            try {
                Thread.sleep(500);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException(e);
            }
        }
        throw new AssertionError("Payment for booking " + bookingId + " never reached " + expectedStatus
                + " within 25s — last observed: " + last);
    }

    private ResponseEntity<Map> getPayment(UUID bookingId, Registered customer) {
        return restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> listRefundRequests(String status, TestPlatformAuth.Registered admin) {
        ResponseEntity<List> response = restTemplate.exchange(
                "/api/v1/platform/payments/refund-requests?status=" + status, HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (List<Map<String, Object>>) response.getBody();
    }

    private TestPlatformAuth.Registered registerPlatformAdmin(String emailPrefix) {
        return TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                emailPrefix + "@factory.internal", PlatformRole.PLATFORM_ADMIN);
    }

    private record BookingForPayment(UUID bookingId, Registered customer) {
    }

    private BookingForPayment createBookingForPayment(String prefix, BigDecimal price) {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, prefix + "customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, prefix + "owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), prefix + "Salon " + runId, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);

        var serviceRequest = new CreateServiceRequest(prefix + "Service", 30, price, "USD");
        UUID serviceId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class).getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId
                + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, price);
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        return new BookingForPayment(UUID.fromString(booking.get("id").toString()), customer);
    }
}
