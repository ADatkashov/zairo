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
 * package-info: no review before completion, no duplicate review, rating
 * validation, and — since both POST /bookings/{id}/complete and
 * POST /bookings/{id}/reviews used to accept calls from anyone at all, with
 * no ownership check — that each is now restricted to the party the
 * workflow actually intends (provider owner for complete, the booking's own
 * customer for reviews).
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
        ResponseEntity<Map> tooEarly = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews",
                HttpMethod.POST, new HttpEntity<>(reviewRequest, TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(tooEarly.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Completing requires CONFIRMED first, which requires payment (ADR-0006).
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        ResponseEntity<Map> completed = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(completed.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(completed.getBody().get("status")).isEqualTo("COMPLETED");

        var invalidRating = new CreateReviewRequest(6, "oops");
        ResponseEntity<Map> badRating = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews",
                HttpMethod.POST, new HttpEntity<>(invalidRating, TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(badRating.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<Map> firstReview = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews",
                HttpMethod.POST, new HttpEntity<>(reviewRequest, TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(firstReview.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(firstReview.getBody().get("rating")).isEqualTo(5);

        ResponseEntity<Map> secondReview = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews",
                HttpMethod.POST, new HttpEntity<>(reviewRequest, TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(secondReview.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        ResponseEntity<Map> fetched = restTemplate.getForEntity("/api/v1/bookings/" + bookingId + "/reviews",
                Map.class);
        assertThat(fetched.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(fetched.getBody().get("comment")).isEqualTo("Great massage!");
    }

    @Test
    void reviewCreationWithoutATokenIs401() {
        BookingContext ctx = createConfirmedBooking("review-no-token");

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/bookings/" + ctx.bookingId()
                + "/reviews", new CreateReviewRequest(5, "Great!"), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void reviewCreationByAnyoneOtherThanTheBookingsOwnCustomerIs403() {
        BookingContext ctx = createConfirmedBooking("review-wrong-customer");
        Registered stranger = TestAuth.registerCustomer(restTemplate, "review-stranger-" + UUID.randomUUID()
                + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + ctx.bookingId() + "/reviews",
                HttpMethod.POST, new HttpEntity<>(new CreateReviewRequest(5, "Not my booking!"),
                        TestAuth.authHeaders(stranger.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void completingABookingWithoutATokenIs401() {
        BookingContext ctx = createConfirmedBooking("complete-no-token");

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/bookings/" + ctx.bookingId()
                + "/complete", null, Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void completingABookingByAnyoneOtherThanItsProvidersOwnerIs403() {
        BookingContext ctx = createConfirmedBooking("complete-wrong-owner");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "complete-other-owner-" + UUID.randomUUID()
                + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + ctx.bookingId() + "/complete",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void onlyTheReviewedProvidersOwnerCanReplyAndReplyingAgainOverwrites() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "reply-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "reply-other-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "reply-customer-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Reply Salon " + runId, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        var serviceRequest = new CreateServiceRequest("Reply Service", 30, new BigDecimal("20.00"), "USD");
        UUID serviceId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class).getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId
                + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("20.00"));
        UUID bookingId = UUID.fromString(restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody()
                .get("id").toString());
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID reviewId = UUID.fromString(restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews",
                HttpMethod.POST, new HttpEntity<>(new CreateReviewRequest(4, "Good, could be faster"),
                        TestAuth.authHeaders(customer.accessToken())), Map.class).getBody().get("id").toString());

        var replyRequest = Map.of("reply", "Thanks for the feedback!");

        // No token -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.postForEntity("/api/v1/reviews/" + reviewId + "/reply",
                replyRequest, Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // A different business owner can't reply.
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/reviews/" + reviewId + "/reply",
                HttpMethod.POST, new HttpEntity<>(replyRequest, TestAuth.authHeaders(otherOwner.accessToken())),
                Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // The real owner can.
        ResponseEntity<Map> replied = restTemplate.exchange("/api/v1/reviews/" + reviewId + "/reply",
                HttpMethod.POST, new HttpEntity<>(replyRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(replied.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(replied.getBody().get("businessReply")).isEqualTo("Thanks for the feedback!");
        assertThat(replied.getBody().get("businessReplyAt")).isNotNull();

        // Replying again overwrites, not rejected as a duplicate.
        var secondReplyRequest = Map.of("reply", "Update: we fixed our scheduling!");
        ResponseEntity<Map> repliedAgain = restTemplate.exchange("/api/v1/reviews/" + reviewId + "/reply",
                HttpMethod.POST, new HttpEntity<>(secondReplyRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(repliedAgain.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(repliedAgain.getBody().get("businessReply")).isEqualTo("Update: we fixed our scheduling!");
    }

    @Test
    void publicReviewsAndSummaryNeedNoTokenAndHideCustomerIdentity() {
        BookingContext ctx = createConfirmedBooking("pub");
        restTemplate.exchange("/api/v1/bookings/" + ctx.bookingId() + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(ctx.owner().accessToken())), Map.class);
        UUID reviewId = UUID.fromString(restTemplate.exchange("/api/v1/bookings/" + ctx.bookingId() + "/reviews",
                HttpMethod.POST, new HttpEntity<>(new CreateReviewRequest(4, "Nice"),
                        TestAuth.authHeaders(ctx.customer().accessToken())), Map.class).getBody().get("id")
                .toString());
        restTemplate.exchange("/api/v1/reviews/" + reviewId + "/reply", HttpMethod.POST,
                new HttpEntity<>(Map.of("reply", "Thanks!"), TestAuth.authHeaders(ctx.owner().accessToken())),
                Map.class);
        UUID providerId = ctx.providerId();

        // No Authorization header on either call.
        ResponseEntity<Map> page = restTemplate.getForEntity("/api/v1/providers/" + providerId
                + "/reviews/public", Map.class);
        assertThat(page.getStatusCode()).isEqualTo(HttpStatus.OK);
        var first = (Map<?, ?>) ((java.util.List<?>) page.getBody().get("content")).get(0);
        assertThat(first.get("comment")).isEqualTo("Nice");
        assertThat(first.get("businessReply")).isEqualTo("Thanks!");
        assertThat(first.containsKey("bookingId")).isFalse();
        assertThat(first.containsKey("userId")).isFalse();
        assertThat(first.containsKey("customerName")).isFalse();
        assertThat(first.get("authorName").toString()).doesNotContain("@");

        // Filters and sort: the only review is 4 stars with text.
        Map<?, ?> fiveStars = restTemplate.getForEntity("/api/v1/providers/" + providerId
                + "/reviews/public?rating=5", Map.class).getBody();
        assertThat((java.util.List<?>) fiveStars.get("content")).isEmpty();
        Map<?, ?> withText = restTemplate.getForEntity("/api/v1/providers/" + providerId
                + "/reviews/public?withComment=true&sort=lowest", Map.class).getBody();
        assertThat((java.util.List<?>) withText.get("content")).hasSize(1);
        assertThat(restTemplate.getForEntity("/api/v1/providers/" + providerId
                + "/reviews/public?sort=bogus", Map.class).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<Map> summary = restTemplate.getForEntity("/api/v1/providers/" + providerId
                + "/reviews/summary", Map.class);
        assertThat(summary.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(summary.getBody().get("total")).isEqualTo(1);
        assertThat(summary.getBody().get("average")).isEqualTo(4.0);
        assertThat(summary.getBody().get("distribution")).isEqualTo(java.util.List.of(0, 0, 0, 1, 0));
    }

    private record BookingContext(Registered owner, Registered customer, UUID bookingId, UUID providerId) {
    }

    /** Owner -> provider -> service -> slot -> booking -> paid (CONFIRMED, not yet completed) — the shared
     * setup the 401/403 tests below need, none of which care about the booking's downstream review.
     * Registration emails stay short (just a fixed prefix + UUID, no seed) — RFC 5321's 64-character
     * local-part limit is real here: the seed-qualified version of this email tipped over it and made
     * every /auth/register call 400 with no "user" in the body, which surfaced downstream as a confusing
     * NPE rather than a clear validation failure. */
    private BookingContext createConfirmedBooking(String seed) {
        Registered owner = TestAuth.registerOwner(restTemplate, "rev-owner-" + UUID.randomUUID()
                + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rev-cust-" + UUID.randomUUID()
                + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Salon " + seed, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        var serviceRequest = new CreateServiceRequest("Service " + seed, 30, new BigDecimal("20.00"), "USD");
        UUID serviceId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class).getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId
                + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("20.00"));
        UUID bookingId = UUID.fromString(restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody()
                .get("id").toString());
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);

        return new BookingContext(owner, customer, bookingId, providerId);
    }
}
