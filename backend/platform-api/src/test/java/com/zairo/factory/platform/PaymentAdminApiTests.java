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

/** Against a real Postgres (Testcontainers) — the admin-only failed-refund visibility list. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class})
class PaymentAdminApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Autowired
    private TestPayments.FailureController failureController;

    @Test
    void listsFailedRefundsForAnyAuthenticatedPlatformRoleButNotForAnonymousCallers() {
        String runId = UUID.randomUUID().toString();
        BookingForPayment bookingForPayment = createBookingForPayment(runId, new BigDecimal("22.00"));
        UUID bookingId = bookingForPayment.bookingId();
        UUID paymentId = UUID.fromString(restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(bookingForPayment.customer().accessToken())), Map.class)
                .getBody().get("id").toString());
        // Refund is PLATFORM_ADMIN-only (see PaymentsController.refund) —
        // needs its own admin account to actually reach PaymentsService and
        // produce the REFUND_FAILED state this test is about.
        var admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "payments-admin-" + runId + "@factory.internal", PlatformRole.PLATFORM_ADMIN);
        failureController.failNextRefund = true;
        restTemplate.exchange("/api/v1/payments/" + paymentId + "/refund", HttpMethod.POST,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);

        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/platform/payments/failed-refunds",
                Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "payments-support-" + runId + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        ResponseEntity<List> response = restTemplate.exchange("/api/v1/platform/payments/failed-refunds",
                HttpMethod.GET, new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())),
                List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).anySatisfy(entry -> {
            Map<?, ?> payment = (Map<?, ?>) entry;
            assertThat(payment.get("id")).isEqualTo(paymentId.toString());
            assertThat(payment.get("status")).isEqualTo("REFUND_FAILED");
            assertThat(payment.get("refundFailureReason")).isEqualTo("simulated refund outage");
        });
    }

    @Test
    void listsRefundOutboxRequestsByStatusForAnyAuthenticatedPlatformRoleButNotForAnonymousCallers() {
        String runId = UUID.randomUUID().toString();
        BookingForPayment bookingForPayment = createBookingForPayment(runId, new BigDecimal("41.00"));
        UUID bookingId = bookingForPayment.bookingId();
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(bookingForPayment.customer().accessToken())), Map.class);
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(bookingForPayment.customer().accessToken())), Map.class);

        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity(
                "/api/v1/platform/payments/refund-requests?status=SUCCEEDED", Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "refund-requests-support-" + runId + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        ResponseEntity<List> response = restTemplate.exchange(
                "/api/v1/platform/payments/refund-requests?status=SUCCEEDED", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())), List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).anySatisfy(entry -> {
            Map<?, ?> refundRequest = (Map<?, ?>) entry;
            assertThat(refundRequest.get("bookingId")).isEqualTo(bookingId.toString());
            assertThat(refundRequest.get("status")).isEqualTo("SUCCEEDED");
            assertThat(refundRequest.get("attempts")).isEqualTo(0);
        });
    }

    private record BookingForPayment(UUID bookingId, Registered customer) {
    }

    private BookingForPayment createBookingForPayment(String runId, BigDecimal price) {
        Registered customer = TestAuth.registerCustomer(restTemplate, "refund-admin-cust-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "refund-admin-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Refund Admin Salon " + runId, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);

        var serviceRequest = new CreateServiceRequest("Refund Admin Service", 30, price, "USD");
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
