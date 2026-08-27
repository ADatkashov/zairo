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

        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/complete", null, Map.class);
        ResponseEntity<Map> payment = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments", null,
                Map.class);
        assertThat(payment.getBody().get("status")).isEqualTo("SUCCEEDED");

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
