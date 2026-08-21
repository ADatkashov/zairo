package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserRole;
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
        UUID customerId = createUser("fav-customer-" + runId + "@example.com", "Fav Customer");
        Registered owner = TestAuth.registerOwner(restTemplate, "fav-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Favorite Test Salon " + runId, "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest("Fav Service", 30, new BigDecimal("15.00"), "USD");
        restTemplate.exchange("/api/v1/providers/" + providerId + "/services", HttpMethod.POST,
                new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);

        // Not favorited yet.
        ResponseEntity<Map> checkBefore = restTemplate.getForEntity(
                "/api/v1/users/" + customerId + "/favorites/" + providerId, Map.class);
        assertThat(checkBefore.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Add favorite — idempotent, calling twice should not error.
        for (int i = 0; i < 2; i++) {
            ResponseEntity<Void> addResponse = restTemplate.postForEntity(
                    "/api/v1/users/" + customerId + "/favorites/" + providerId, null, Void.class);
            assertThat(addResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        }

        ResponseEntity<Map> checkAfter = restTemplate.getForEntity(
                "/api/v1/users/" + customerId + "/favorites/" + providerId, Map.class);
        assertThat(checkAfter.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map[]> listResponse = restTemplate.getForEntity(
                "/api/v1/users/" + customerId + "/favorites", Map[].class);
        assertThat(listResponse.getBody()).hasSize(1);
        assertThat(listResponse.getBody()[0].get("id")).isEqualTo(providerId.toString());
        assertThat(listResponse.getBody()[0].get("services")).asList().hasSize(1);

        // Remove — idempotent, calling twice should not error.
        for (int i = 0; i < 2; i++) {
            ResponseEntity<Void> removeResponse = restTemplate.exchange(
                    "/api/v1/users/" + customerId + "/favorites/" + providerId,
                    org.springframework.http.HttpMethod.DELETE, null, Void.class);
            assertThat(removeResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        }

        ResponseEntity<Map> checkFinal = restTemplate.getForEntity(
                "/api/v1/users/" + customerId + "/favorites/" + providerId, Map.class);
        assertThat(checkFinal.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void favoritedProviderSurfacesAverageRatingAndReviewCount() {
        String runId = UUID.randomUUID().toString();
        UUID customerId = createUser("fav-rating-customer-" + runId + "@example.com", "Fav Rating Customer");
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
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());
        var bookingRequest = new CreateBookingRequest(reviewer.userId(), serviceId, slotId, new BigDecimal("15.00"));
        Map<?, ?> booking = restTemplate.postForEntity("/api/v1/bookings", bookingRequest, Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/complete", null, Map.class);
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/reviews", new CreateReviewRequest(5, null),
                Map.class);

        restTemplate.postForEntity("/api/v1/users/" + customerId + "/favorites/" + providerId, null, Void.class);

        ResponseEntity<Map[]> listResponse = restTemplate.getForEntity(
                "/api/v1/users/" + customerId + "/favorites", Map[].class);
        Map favorited = listResponse.getBody()[0];
        assertThat(((Number) favorited.get("averageRating")).doubleValue()).isEqualTo(5.0);
        assertThat(((Number) favorited.get("reviewCount")).longValue()).isEqualTo(1L);
    }

    private UUID createUser(String email, String displayName) {
        var request = new CreateUserRequest(email, "+1000000000", displayName, UserRole.CUSTOMER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
