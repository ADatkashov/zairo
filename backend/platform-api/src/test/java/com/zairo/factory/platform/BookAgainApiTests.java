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

/** Against a real Postgres (Testcontainers) — "book again" suggestions from real completed bookings. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class BookAgainApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void suggestsTheMostRecentCompletedServiceAndOnlySelfServiceCanReadIt() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "bookagain-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "bookagain-cust-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate,
                "bookagain-other-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Book Again Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Haircut " + runId, new BigDecimal("25.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("25.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/complete", null, Map.class);

        ResponseEntity<Map> forbidden = restTemplate.exchange(
                "/api/v1/users/" + customer.userId() + "/book-again", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<List> response = restTemplate.exchange("/api/v1/users/" + customer.userId() + "/book-again",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(1);
        Map<?, ?> suggestion = (Map<?, ?>) response.getBody().get(0);
        assertThat(suggestion.get("providerId")).isEqualTo(providerId.toString());
        assertThat(suggestion.get("providerName")).isEqualTo("Book Again Salon " + runId);
        assertThat(suggestion.get("vertical")).isEqualTo("beauty");
        assertThat(suggestion.get("serviceId")).isEqualTo(serviceId.toString());
        assertThat(suggestion.get("serviceTitle")).isEqualTo("Haircut " + runId);
        assertThat(((Number) suggestion.get("price")).doubleValue()).isEqualTo(25.00);
        assertThat(suggestion.get("lastVisitAt")).isNotNull();

        ResponseEntity<List> emptyForOther = restTemplate.exchange(
                "/api/v1/users/" + otherCustomer.userId() + "/book-again", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())), List.class);
        assertThat(emptyForOther.getBody()).isEmpty();
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
