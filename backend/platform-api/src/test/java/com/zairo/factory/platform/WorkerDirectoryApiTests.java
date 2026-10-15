package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.staff.StaffBookingDtos.CreateStaffBookingRequest;
import com.zairo.factory.staff.StaffDtos.CreateStaffRequest;
import com.zairo.factory.users.UserRepository;
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
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Against a real Postgres (Testcontainers): GET /workers/top ranks workers by the average rating of
 * the reviews left on their bookings, only counts masters with enough reviews, and only shows
 * active masters of ACTIVE providers.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class WorkerDirectoryApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void ranksByAverageRatingAndNeedsThreeReviews() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "top-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Top Studio " + runId);
        approve(providerId);
        UUID serviceId = createService(owner, providerId);

        UUID best = createStaff(owner, providerId, "Best Master");
        UUID good = createStaff(owner, providerId, "Good Master");
        UUID newcomer = createStaff(owner, providerId, "Newcomer");
        for (UUID staffId : List.of(best, good, newcomer)) {
            restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.POST,
                    new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        }

        int hour = 1;
        for (int rating : new int[] {5, 5, 4}) {
            review(owner, providerId, serviceId, best, rating, hour++, runId);
        }
        for (int rating : new int[] {4, 4, 4}) {
            review(owner, providerId, serviceId, good, rating, hour++, runId);
        }
        // A single perfect review is not enough to be called one of the best.
        review(owner, providerId, serviceId, newcomer, 5, hour++, runId);

        List<Map> top = getTop(20);
        List<String> ids = top.stream().map(m -> m.get("id").toString()).toList();

        assertThat(ids).contains(best.toString(), good.toString()).doesNotContain(newcomer.toString());
        assertThat(ids.indexOf(best.toString())).isLessThan(ids.indexOf(good.toString()));
        Map<?, ?> first = top.get(ids.indexOf(best.toString()));
        assertThat(first.get("displayName")).isEqualTo("Best Master");
        assertThat(first.get("providerId")).isEqualTo(providerId.toString());
        assertThat(first.get("providerName")).isEqualTo("Top Studio " + runId);
        assertThat(((Number) first.get("averageRating")).doubleValue()).isEqualTo(4.7);
        assertThat(((Number) first.get("reviewCount")).longValue()).isEqualTo(3L);
    }

    @Test
    void deactivatedMastersAndNonActiveProvidersAreLeftOut() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "top-hidden-owner-" + runId + "@example.com");
        UUID activeProvider = createProvider(owner, "Visible " + runId);
        approve(activeProvider);
        UUID pendingProvider = createProvider(owner, "Pending " + runId);
        UUID activeService = createService(owner, activeProvider);
        UUID pendingService = createService(owner, pendingProvider);

        UUID retired = createStaff(owner, activeProvider, "Retired Master");
        UUID unapproved = createStaff(owner, pendingProvider, "Unapproved Master");
        restTemplate.exchange("/api/v1/staff/" + retired + "/services/" + activeService, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        restTemplate.exchange("/api/v1/staff/" + unapproved + "/services/" + pendingService, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);

        int hour = 1;
        for (int i = 0; i < 3; i++) {
            review(owner, activeProvider, activeService, retired, 5, hour++, runId);
            review(owner, pendingProvider, pendingService, unapproved, 5, hour++, runId);
        }
        restTemplate.exchange("/api/v1/staff/" + retired, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);

        List<String> ids = getTop(20).stream().map(m -> m.get("id").toString()).toList();

        assertThat(ids).doesNotContain(retired.toString(), unapproved.toString());
    }

    @Test
    void aWorkersPublicPageShowsRatingAndServicesAndHidesUnknownAndInactiveOnes() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "page-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Page Studio " + runId);
        approve(providerId);
        UUID serviceId = createService(owner, providerId);
        UUID staffId = createStaff(owner, providerId, "Page Master");
        restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);

        // No reviews yet: the page exists, with no rating.
        ResponseEntity<Map> fresh = restTemplate.getForEntity("/api/v1/workers/" + staffId, Map.class);
        assertThat(fresh.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(fresh.getBody().get("averageRating")).isNull();
        assertThat(((Number) fresh.getBody().get("reviewCount")).longValue()).isZero();
        assertThat(fresh.getBody().get("providerName")).isEqualTo("Page Studio " + runId);
        assertThat((List<?>) fresh.getBody().get("services")).hasSize(1);

        review(owner, providerId, serviceId, staffId, 4, 1, runId);
        review(owner, providerId, serviceId, staffId, 5, 2, runId);
        Map<?, ?> page = restTemplate.getForEntity("/api/v1/workers/" + staffId, Map.class).getBody();
        assertThat(((Number) page.get("averageRating")).doubleValue()).isEqualTo(4.5);
        assertThat(((Number) page.get("reviewCount")).longValue()).isEqualTo(2L);

        assertThat(restTemplate.getForEntity("/api/v1/workers/" + UUID.randomUUID(), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.NOT_FOUND);

        restTemplate.exchange("/api/v1/staff/" + staffId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(restTemplate.getForEntity("/api/v1/workers/" + staffId, Map.class).getStatusCode())
                .isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void theCityFilterKeepsThatCitysBusinessesAndThoseWithoutACity() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "city-owner-" + runId + "@example.com");
        UUID[] staff = new UUID[3];
        String[] cities = {"almaty", "aktau", null};
        for (int i = 0; i < 3; i++) {
            UUID providerId = createProvider(owner, "City Studio " + i + " " + runId);
            approve(providerId);
            jdbcTemplate.update("update provider set city_code = ? where id = ?", cities[i], providerId);
            UUID serviceId = createService(owner, providerId);
            staff[i] = createStaff(owner, providerId, "City Master " + i);
            restTemplate.exchange("/api/v1/staff/" + staff[i] + "/services/" + serviceId, HttpMethod.POST,
                    new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
            for (int r = 0; r < 3; r++) {
                review(owner, providerId, serviceId, staff[i], 5, r + 1 + i * 3, runId);
            }
        }

        ResponseEntity<Map[]> response = restTemplate.getForEntity("/api/v1/workers/top?limit=20&city=almaty",
                Map[].class);
        List<String> ids = List.of(response.getBody()).stream().map(m -> m.get("id").toString()).toList();

        assertThat(ids).contains(staff[0].toString(), staff[2].toString()).doesNotContain(staff[1].toString());
        assertThat(getTop(20).stream().map(m -> m.get("id").toString()).toList()).contains(staff[0].toString(),
                staff[1].toString(), staff[2].toString());
    }

    @Test
    void limitIsClampedAndNeedsNoToken() {
        assertThat(getTop(0).size()).isLessThanOrEqualTo(1);
        assertThat(getTop(1000).size()).isLessThanOrEqualTo(20);
    }

    private List<Map> getTop(int limit) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity("/api/v1/workers/top?limit=" + limit, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    /** A completed, paid booking with the master and a review of {@code rating} by a fresh customer. */
    private void review(Registered owner, UUID providerId, UUID serviceId, UUID staffId, int rating, int hour,
            String runId) {
        Registered customer = TestAuth.registerCustomer(restTemplate, "top-cust-" + UUID.randomUUID() + "-" + runId
                + "@example.com");
        Instant start = Instant.now().plus(hour, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(60, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId
                + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        ResponseEntity<Map> booked = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customer.userId(), staffId, serviceId, slotId,
                        new BigDecimal("30.00")), TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(booked.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String bookingId = booked.getBody().get("bookingId").toString();
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        ResponseEntity<Map> reviewed = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews",
                HttpMethod.POST, new HttpEntity<>(new CreateReviewRequest(rating, "ok"),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(reviewed.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    private void approve(UUID providerId) {
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "top-admin-" + UUID.randomUUID() + "@example.com");
        var request = new UpdateProviderStatusRequest(ProviderStatus.ACTIVE);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/status",
                HttpMethod.PATCH, new HttpEntity<>(request, TestAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString(response.getBody().get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        return providerId;
    }

    private UUID createService(Registered owner, UUID providerId) {
        var request = new CreateServiceRequest("Haircut", 60, new BigDecimal("30.00"), "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createStaff(Registered owner, UUID providerId, String displayName) {
        var request = new CreateStaffRequest(displayName, "Bio", null);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/staff",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
