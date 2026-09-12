package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.customerintelligence.CustomerIntelligenceService;
import com.zairo.factory.customerintelligence.CustomerProfile;
import com.zairo.factory.customerintelligence.CustomerProfileRepository;
import com.zairo.factory.customerintelligence.CustomerProviderProfile;
import com.zairo.factory.customerintelligence.CustomerProviderProfileRepository;
import com.zairo.factory.customerintelligence.RetentionStatus;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.smartfill.SmartFillCampaign;
import com.zairo.factory.smartfill.SmartFillCampaignRepository;
import com.zairo.factory.smartfill.CandidateOffer;
import com.zairo.factory.smartfill.CandidateOfferRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
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
 * End-to-end against a real Postgres (Testcontainers), same style as {@link
 * RebookApiTests}. Covers the parts that genuinely need the whole app wired
 * together -- event-driven recalculation, authorization/cross-business
 * isolation, and the Smart Fill integration; the deterministic calculation
 * core itself (data-quality rules, retention thresholds, the value score)
 * has its own fast unit tests in {@code customer-intelligence}'s own
 * {@code src/test}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestClock.class})
class CustomerIntelligenceApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private CustomerProfileRepository profileRepository;

    @Autowired
    private CustomerProviderProfileRepository providerProfileRepository;

    @Autowired
    private CustomerIntelligenceService customerIntelligenceService;

    @Autowired
    private SmartFillCampaignRepository smartFillCampaignRepository;

    @Autowired
    private CandidateOfferRepository candidateOfferRepository;

    @Autowired
    private MutableClock clock;

    @BeforeEach
    void resetClockToRealNow() {
        clock.advanceTo(Instant.now());
    }

    @Test
    void aFreshCustomerWithNoBookingsHasAnEmptyNewProfile() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "ci-empty-" + runId + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/me/customer-intelligence", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("totalCompletedBookings")).isEqualTo(0);
        assertThat(response.getBody().get("retentionStatus")).isEqualTo("NEW");
        assertThat(response.getBody().get("favouriteProviderId")).isNull();
    }

    @Test
    void completingABookingUpdatesBothTheGlobalAndBusinessProfiles() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ci-complete-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "ci-complete-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CI Complete Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CI Complete Service", new BigDecimal("40.00"));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(2, ChronoUnit.DAYS));

        CustomerProfile profile = profileRepository.findByUserId(customer.userId()).orElseThrow();
        assertThat(profile.getTotalCompletedBookings()).isEqualTo(1);
        assertThat(profile.getTotalSpent()).isEqualByComparingTo("40.00");
        assertThat(profile.getFavouriteProviderId()).isEqualTo(providerId);
        assertThat(profile.getFavouriteServiceId()).isEqualTo(serviceId);

        CustomerProviderProfile providerProfile = providerProfileRepository
                .findByUserIdAndProviderId(customer.userId(), providerId).orElseThrow();
        assertThat(providerProfile.getCompletedBookings()).isEqualTo(1);
        assertThat(providerProfile.getTotalSpent()).isEqualByComparingTo("40.00");
        assertThat(providerProfile.getFavouriteServiceId()).isEqualTo(serviceId);

        ResponseEntity<Map> ownerView = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/customers/" + customer.userId() + "/intelligence",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(ownerView.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(ownerView.getBody().get("completedBookings")).isEqualTo(1);
    }

    @Test
    void cancelledAndNoShowBookingsNeverCountAsCompletedVisitsOrSpend() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ci-cancel-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "ci-cancel-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CI Cancel Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CI Cancel Service", new BigDecimal("60.00"));

        Instant cancelledStart = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID cancelledSlot = createSlot(owner, providerId, cancelledStart, cancelledStart.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(customer, providerId, serviceId, cancelledSlot);
        cancelBooking(customer, cancelledBookingId);

        Instant noShowStart = Instant.now().minus(1, ChronoUnit.DAYS);
        UUID noShowSlot = createSlot(owner, providerId, noShowStart, noShowStart.plus(30, ChronoUnit.MINUTES));
        UUID noShowBookingId = createBooking(customer, providerId, serviceId, noShowSlot);
        payBooking(customer, noShowBookingId);
        markNoShow(owner, noShowBookingId);

        CustomerProfile profile = profileRepository.findByUserId(customer.userId()).orElseThrow();
        assertThat(profile.getTotalCompletedBookings()).isEqualTo(0);
        assertThat(profile.getTotalCancelledBookings()).isEqualTo(1);
        assertThat(profile.getTotalNoShows()).isEqualTo(1);
        assertThat(profile.getTotalSpent()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(profile.getAttendanceRate()).isEqualTo(0.0);
    }

    @Test
    void aBusinessCannotSeeAnotherBusinessesCustomerIntelligence() {
        String runId = UUID.randomUUID().toString();
        Registered ownerA = TestAuth.registerOwner(restTemplate, "ci-isolation-ownerA-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "ci-isolation-ownerB-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "ci-isolation-customer-" + runId + "@example.com");

        UUID providerA = createProvider(ownerA, "CI Isolation Salon A " + runId);
        UUID serviceA = createService(ownerA, providerA, "CI Isolation Service A", new BigDecimal("30.00"));
        completeVisit(ownerA, customer, providerA, serviceA, Instant.now().minus(1, ChronoUnit.DAYS));

        UUID providerB = createProvider(ownerB, "CI Isolation Salon B " + runId);
        UUID serviceB = createService(ownerB, providerB, "CI Isolation Service B", new BigDecimal("999.00"));
        completeVisit(ownerB, customer, providerB, serviceB, Instant.now().minus(1, ChronoUnit.DAYS));

        // Business A's own view of this customer must reflect only business A's own bookings.
        CustomerProviderProfile profileAtA = providerProfileRepository
                .findByUserIdAndProviderId(customer.userId(), providerA).orElseThrow();
        assertThat(profileAtA.getCompletedBookings()).isEqualTo(1);
        assertThat(profileAtA.getTotalSpent()).isEqualByComparingTo("30.00");

        // Business B's owner cannot read business A's relationship with this same customer.
        ResponseEntity<Map> forbidden = restTemplate.exchange(
                "/api/v1/providers/" + providerA + "/customers/" + customer.userId() + "/intelligence",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(ownerB.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void repeatedRecalculationForTheSameHistoryIsIdempotent() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ci-idempotent-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "ci-idempotent-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CI Idempotent Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CI Idempotent Service", new BigDecimal("22.00"));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(3, ChronoUnit.DAYS));

        // Simulates a duplicated BookingCompletedEvent delivery, or a manual/scheduled re-recalculation.
        customerIntelligenceService.recalculateProfile(customer.userId());
        customerIntelligenceService.recalculateProfile(customer.userId());
        customerIntelligenceService.recalculateProviderProfile(customer.userId(), providerId);

        CustomerProfile profile = profileRepository.findByUserId(customer.userId()).orElseThrow();
        assertThat(profile.getTotalCompletedBookings()).isEqualTo(1);
        assertThat(profile.getTotalSpent()).isEqualByComparingTo("22.00");
    }

    @Test
    void smartFillOffersACandidateFlaggedAsDueForRebookingByCustomerIntelligence() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ci-revenue-owner-" + runId + "@example.com");
        Registered candidate = TestAuth.registerCustomer(restTemplate, "ci-revenue-candidate-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "ci-revenue-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CI Revenue Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CI Revenue Service", new BigDecimal("35.00"));

        // Establish a 14-day cadence for the candidate at this provider (visits 44 and 30 days ago),
        // then land in the AT_RISK/DUE_FOR_REBOOKING band relative to that cadence: 30 days since the
        // last visit is beyond atRiskFactor (2.0 x 14 = 28) but within inactiveFactor (3.0 x 14 = 42).
        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        completeVisit(owner, candidate, providerId, serviceId, today.minus(44, ChronoUnit.DAYS));
        completeVisit(owner, candidate, providerId, serviceId, today.minus(30, ChronoUnit.DAYS));

        CustomerProviderProfile profile = providerProfileRepository
                .findByUserIdAndProviderId(candidate.userId(), providerId).orElseThrow();
        assertThat(profile.getAverageVisitIntervalDays()).isEqualTo(14);
        assertThat(profile.getRetentionStatus()).isIn(RetentionStatus.DUE_FOR_REBOOKING, RetentionStatus.AT_RISK);

        // A different customer's slot frees up -- the overdue candidate has no history with this
        // exact freed service/time, only PREVIOUS_PROVIDER_BOOKING plus the new intelligence signal.
        Instant freedStart = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID freedSlot = createSlot(owner, providerId, freedStart, freedStart.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, freedSlot);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = smartFillCampaignRepository.findByCancelledBookingId(cancelledBookingId)
                .orElseThrow();
        List<CandidateOffer> offers = candidateOfferRepository.findByCampaignId(campaign.getId());
        CandidateOffer candidateOffer = offers.stream().filter(o -> o.getUserId().equals(candidate.userId()))
                .findFirst().orElseThrow();
        assertThat(candidateOffer.getMatchedFactors()).contains("DUE_FOR_REBOOKING");
    }

    private void completeVisit(Registered owner, Registered customer, UUID providerId, UUID serviceId,
            Instant startsAt) {
        UUID slotId = createSlot(owner, providerId, startsAt, startsAt.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        payBooking(customer, bookingId);
        completeBooking(owner, bookingId);
    }

    private void payBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    private void completeBooking(Registered owner, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
    }

    private void cancelBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private void markNoShow(Registered owner, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/no-show",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
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

    private UUID createBooking(Registered customer, UUID providerId, UUID serviceId, UUID slotId) {
        var request = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("0.00"));
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
