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
 * End-to-end: owner -> provider -> service -> slot -> booking -> complete ->
 * review, against a real Postgres (Testcontainers). Also proves the "no
 * review without a verified visit" rule from the reviews module's
 * package-info: no review before completion, no duplicate review, and
 * rating validation.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class ReviewApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void reviewRequiresACompletedBookingAndAllowsOnlyOnePerBooking() {
        Registered owner = TestAuth.registerOwner(restTemplate, "owner4@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "customer4@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Fourth Salon", "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest("Massage", 60, new BigDecimal("50.00"), "USD");
        ResponseEntity<Map> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        UUID serviceId = UUID.fromString(serviceResponse.getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(60, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("50.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());

        var reviewRequest = new CreateReviewRequest(5, "Great massage!");
        ResponseEntity<Map> tooEarly = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/reviews",
                reviewRequest, Map.class);
        assertThat(tooEarly.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Completing requires CONFIRMED first, which requires payment (ADR-0006).
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments", null, Map.class);
        ResponseEntity<Map> completed = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/complete",
                null, Map.class);
        assertThat(completed.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(completed.getBody().get("status")).isEqualTo("COMPLETED");

        var invalidRating = new CreateReviewRequest(6, "oops");
        ResponseEntity<Map> badRating = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/reviews",
                invalidRating, Map.class);
        assertThat(badRating.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<Map> firstReview = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/reviews",
                reviewRequest, Map.class);
        assertThat(firstReview.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(firstReview.getBody().get("rating")).isEqualTo(5);

        ResponseEntity<Map> secondReview = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/reviews",
                reviewRequest, Map.class);
        assertThat(secondReview.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        ResponseEntity<Map> fetched = restTemplate.getForEntity("/api/v1/bookings/" + bookingId + "/reviews",
                Map.class);
        assertThat(fetched.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(fetched.getBody().get("comment")).isEqualTo("Great massage!");
    }
}
