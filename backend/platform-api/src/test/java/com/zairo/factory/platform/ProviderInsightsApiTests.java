package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
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
 * Against a real Postgres (Testcontainers) — the customer-history read
 * composed live from Booking/Payment/ServiceOffering/User, not a separate
 * CRM table (see ProviderInsightsService's doc comment).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class ProviderInsightsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void summarizesACustomersBookingsSpendAndFavoriteService() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "insights-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Insights Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Haircut " + runId, new BigDecimal("30.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        Registered customer = TestAuth.registerCustomer(restTemplate,
                "insights-customer-" + runId + "@example.com");
        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("30.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());

        // Completing requires CONFIRMED first, which requires payment (ADR-0006).
        ResponseEntity<Map> payment = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(payment.getBody().get("status")).isEqualTo("SUCCEEDED");
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);

        ResponseEntity<List> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/customers",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(1);
        Map<?, ?> summary = (Map<?, ?>) response.getBody().get(0);
        assertThat(summary.get("userId")).isEqualTo(customer.userId().toString());
        assertThat(summary.get("totalBookings")).isEqualTo(1);
        assertThat(summary.get("completedBookings")).isEqualTo(1);
        assertThat(((Number) summary.get("totalSpent")).doubleValue()).isEqualTo(30.00);
        assertThat(summary.get("currency")).isEqualTo("USD");
        assertThat(summary.get("lastVisitAt")).isNotNull();
        assertThat(summary.get("favoriteServiceTitle")).isEqualTo("Haircut " + runId);
    }

    @Test
    void onlyTheOwnerCanReadCustomerHistoryAndAFreshProviderHasNone() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "insights-owner2-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate,
                "insights-other-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Empty Insights Salon " + runId);

        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/providers/" + providerId + "/customers",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<List> ownResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/customers",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(ownResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(ownResponse.getBody()).isEmpty();
    }

    @Test
    void computesDashboardMetricsFromRealBookingsAndPayments() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "dash-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Dashboard Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Manicure " + runId, new BigDecimal("40.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        Registered completedCustomer = TestAuth.registerCustomer(restTemplate,
                "dash-completed-" + runId + "@example.com");
        UUID completedSlot = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID completedBookingId = book(completedCustomer, serviceId, completedSlot, new BigDecimal("40.00"));
        // Completing requires CONFIRMED first, which requires payment (ADR-0006).
        restTemplate.exchange("/api/v1/bookings/" + completedBookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(completedCustomer.accessToken())), Map.class);
        restTemplate.exchange("/api/v1/bookings/" + completedBookingId + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);

        Registered cancelledCustomer = TestAuth.registerCustomer(restTemplate,
                "dash-cancelled-" + runId + "@example.com");
        UUID cancelledSlot = createSlot(owner, providerId, start.plus(1, ChronoUnit.HOURS),
                start.plus(90, ChronoUnit.MINUTES));
        UUID cancelledBookingId = book(cancelledCustomer, serviceId, cancelledSlot, new BigDecimal("40.00"));
        restTemplate.exchange("/api/v1/bookings/" + cancelledBookingId + "/cancel", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(cancelledCustomer.accessToken())), Map.class);

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/dashboard",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> metrics = response.getBody();
        assertThat(metrics.get("totalBookings")).isEqualTo(2);
        assertThat(metrics.get("completedBookings")).isEqualTo(1);
        assertThat(metrics.get("cancelledBookings")).isEqualTo(1);
        assertThat(((Number) metrics.get("cancellationRate")).doubleValue()).isEqualTo(0.5);
        assertThat(metrics.get("totalCustomers")).isEqualTo(2);
        assertThat(((Number) metrics.get("totalRevenue")).doubleValue()).isEqualTo(40.00);
        assertThat(((Number) metrics.get("averageCheck")).doubleValue()).isEqualTo(40.00);
        assertThat(metrics.get("currency")).isEqualTo("USD");
        List<?> topServices = (List<?>) metrics.get("topServices");
        assertThat(topServices).hasSize(1);
        Map<?, ?> topService = (Map<?, ?>) topServices.get(0);
        assertThat(topService.get("title")).isEqualTo("Manicure " + runId);
        assertThat(topService.get("bookingCount")).isEqualTo(2);
    }

    @Test
    void onlyTheOwnerCanReadDashboardMetricsAndAFreshProviderIsAllZero() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "dash-owner2-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "dash-other-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Empty Dashboard Salon " + runId);

        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/providers/" + providerId + "/dashboard",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Map> ownResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/dashboard",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(ownResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> metrics = ownResponse.getBody();
        assertThat(metrics.get("totalBookings")).isEqualTo(0);
        assertThat(((Number) metrics.get("cancellationRate")).doubleValue()).isEqualTo(0.0);
        assertThat(metrics.get("averageCheck")).isNull();
        assertThat(metrics.get("currency")).isNull();
        assertThat((List<?>) metrics.get("topServices")).isEmpty();
    }

    private UUID book(Registered customer, UUID serviceId, UUID slotId, BigDecimal price) {
        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, price);
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        return UUID.fromString(booking.get("id").toString());
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
}
