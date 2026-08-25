package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
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
 * Against a real Postgres (Testcontainers): favorite -> check -> list ->
 * unfavorite -> check again, plus idempotency of add/remove.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class FavoritesApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void favoritesAProviderThenUnfavoritesIt() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "fav-customer-" + runId + "@example.com");
        UUID customerId = customer.userId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken()));
        Registered owner = TestAuth.registerOwner(restTemplate, "fav-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Favorite Test Salon " + runId, "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest("Fav Service", 30, new BigDecimal("15.00"), "USD");
        restTemplate.exchange("/api/v1/providers/" + providerId + "/services", HttpMethod.POST,
                new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);

        // Not favorited yet.
        ResponseEntity<Map> checkBefore = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/favorites/" + providerId, HttpMethod.GET, customerAuth, Map.class);
        assertThat(checkBefore.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Add favorite — idempotent, calling twice should not error.
        for (int i = 0; i < 2; i++) {
            ResponseEntity<Void> addResponse = restTemplate.exchange(
                    "/api/v1/users/" + customerId + "/favorites/" + providerId, HttpMethod.POST, customerAuth,
                    Void.class);
            assertThat(addResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        }

        ResponseEntity<Map> checkAfter = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/favorites/" + providerId, HttpMethod.GET, customerAuth, Map.class);
        assertThat(checkAfter.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map[]> listResponse = restTemplate.exchange("/api/v1/users/" + customerId + "/favorites",
                HttpMethod.GET, customerAuth, Map[].class);
        assertThat(listResponse.getBody()).hasSize(1);
        assertThat(listResponse.getBody()[0].get("id")).isEqualTo(providerId.toString());
        assertThat(listResponse.getBody()[0].get("services")).asList().hasSize(1);

        // Remove — idempotent, calling twice should not error.
        for (int i = 0; i < 2; i++) {
            ResponseEntity<Void> removeResponse = restTemplate.exchange(
                    "/api/v1/users/" + customerId + "/favorites/" + providerId, HttpMethod.DELETE, customerAuth,
                    Void.class);
            assertThat(removeResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        }

        ResponseEntity<Map> checkFinal = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/favorites/" + providerId, HttpMethod.GET, customerAuth, Map.class);
        assertThat(checkFinal.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void favoritedProviderSurfacesAverageRatingAndReviewCount() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "fav-rating-customer-" + runId + "@example.com");
        UUID customerId = customer.userId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken()));
        Registered owner = TestAuth.registerOwner(restTemplate, "fav-rating-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Fav Rating Salon " + runId, "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest("Fav Rating Service", 30, new BigDecimal("15.00"), "USD");
        ResponseEntity<Map> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        UUID serviceId = UUID.fromString(serviceResponse.getBody().get("id").toString());

        Registered reviewer = TestAuth.registerCustomer(restTemplate,
                "fav-rating-reviewer-" + runId + "@example.com");
        var reviewerAuth = new HttpEntity<>(null, TestAuth.authHeaders(reviewer.accessToken()));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());
        var bookingRequest = new CreateBookingRequest(reviewer.userId(), serviceId, slotId, new BigDecimal("15.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(reviewer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/complete", null, Map.class);
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews", HttpMethod.POST,
                new HttpEntity<>(new CreateReviewRequest(5, null), TestAuth.authHeaders(reviewer.accessToken())),
                Map.class);

        restTemplate.exchange("/api/v1/users/" + customerId + "/favorites/" + providerId, HttpMethod.POST,
                customerAuth, Void.class);

        ResponseEntity<Map[]> listResponse = restTemplate.exchange("/api/v1/users/" + customerId + "/favorites",
                HttpMethod.GET, customerAuth, Map[].class);
        Map favorited = listResponse.getBody()[0];
        assertThat(((Number) favorited.get("averageRating")).doubleValue()).isEqualTo(5.0);
        assertThat(((Number) favorited.get("reviewCount")).longValue()).isEqualTo(1L);
    }
}
