package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.reactivationengine.ReactivationCampaign;
import com.zairo.factory.reactivationengine.ReactivationCampaignRepository;
import com.zairo.factory.reactivationengine.ReactivationCampaignService;
import com.zairo.factory.reactivationengine.ReactivationCampaignStatus;
import com.zairo.factory.reactivationengine.ReactivationDiscoveryService;
import com.zairo.factory.reactivationengine.ReactivationProperties;
import com.zairo.factory.revenueengine.ActionType;
import com.zairo.factory.revenueengine.RevenueOutcome;
import com.zairo.factory.revenueengine.RevenueOutcomeRepository;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
 * RebookApiTests}. Visit timestamps are always backdated via real
 * wall-clock arithmetic ({@code Instant.now().minus(...)}) rather than by
 * advancing {@link TestClock}'s shared {@link MutableClock} forward --
 * {@code ReactivationDiscoveryService#scanForInactiveCustomers} is a
 * platform-wide sweep with no per-provider/per-booking scoping, and this
 * suite's Spring context (hence its {@link MutableClock} bean and its
 * Testcontainers Postgres instance) may be shared with other *ApiTests
 * classes in a full suite run; moving "now" forward would risk sweeping up
 * unrelated fixtures from those classes, whereas backdating only this
 * suite's own visits does not. Every assertion here is scoped to this
 * test's own booking/campaign ids for the same reason -- never a global
 * count.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestClock.class})
class ReactivationApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

    @Autowired
    private ReactivationCampaignService reactivationCampaignService;

    @Autowired
    private ReactivationDiscoveryService reactivationDiscoveryService;

    @Autowired
    private ReactivationCampaignRepository campaignRepository;

    @Autowired
    private ReactivationProperties reactivationProperties;

    @Autowired
    private RevenueOutcomeRepository revenueOutcomeRepository;

    @Autowired
    private MutableClock clock;

    @BeforeEach
    void resetClockToRealNow() {
        clock.advanceTo(Instant.now());
    }

    @Test
    void aSingleVisitCustomerIsFlaggedOncePastTheAbsoluteInactivityCeiling() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-single-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rx-single-customer-" + runId + "@example.com");
        String customerEmail = "rx-single-customer-" + runId + "@example.com";
        UUID providerId = createProvider(owner, "RX Single Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Single Service", new BigDecimal("40.00"));

        // Well past the absolute ceiling (default 120 days) -- a single
        // visit has no established pattern, so only the ceiling applies.
        UUID visitId = createCompletedVisit(owner, customer, providerId, serviceId,
                Instant.now().minus(reactivationProperties.absoluteMaxInactivityDays() + 10, ChronoUnit.DAYS));

        reactivationDiscoveryService.scanForInactiveCustomers();

        ReactivationCampaign campaign = campaignRepository.findAll().stream()
                .filter(c -> c.getLastVisitBookingId().equals(visitId)).findFirst().orElseThrow();
        assertThat(campaign.getProviderId()).isEqualTo(providerId);
        assertThat(campaign.getUserId()).isEqualTo(customer.userId());
        assertThat(campaign.getStatus()).isEqualTo(ReactivationCampaignStatus.SENT);

        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(customerEmail);
            assertThat(email.subject()).isEqualTo("We miss you!");
            assertThat(email.body()).contains("RX Single Service").contains("RX Single Salon " + runId);
        });

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.CUSTOMER_REACTIVATION, visitId).orElseThrow();
        assertThat(outcome.getRecovered()).isNull();
        assertThat(outcome.getActualRevenue()).isNull();
    }

    @Test
    void aSingleVisitCustomerIsNotFlaggedBeforeTheAbsoluteInactivityCeiling() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-early-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rx-early-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RX Early Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Early Service", new BigDecimal("20.00"));

        // Past the scan floor (default 45 days) but nowhere near the
        // absolute ceiling (default 120), and no established pattern.
        UUID visitId = createCompletedVisit(owner, customer, providerId, serviceId,
                Instant.now().minus(reactivationProperties.scanMinimumInactivityDays() + 5, ChronoUnit.DAYS));

        reactivationDiscoveryService.scanForInactiveCustomers();

        assertThat(campaignRepository.existsByLastVisitBookingId(visitId)).isFalse();
    }

    @Test
    void aPatternedCustomerIsFlaggedOncePastTheirPersonalIntervalThreshold() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-pattern-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rx-pattern-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RX Pattern Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Pattern Service", new BigDecimal("45.00"));

        // Two visits 35 days apart establish an average interval; 35 x the
        // default 2.0 multiplier = 70 days -- comfortably past the flat
        // 45-day scan floor but well under the 120-day absolute ceiling, so
        // only the personalized threshold explains a flag here. One extra
        // day of margin past the 70-day threshold itself, since the test
        // clock is frozen a few milliseconds before these Instant.now()
        // calls -- an exact-boundary gap would truncate (via Duration#toDays)
        // to just under the threshold and flakily miss it. Truncated to
        // whole days (matching RebookApiTests' own convention) so the
        // round-tripped timestamptz (microsecond precision) compares equal
        // to the in-memory Instant (nanosecond precision) below.
        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        Instant firstVisit = today.minus(106, ChronoUnit.DAYS);
        Instant lastVisit = firstVisit.plus(35, ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, firstVisit);
        UUID lastVisitId = createCompletedVisit(owner, customer, providerId, serviceId, lastVisit);

        reactivationDiscoveryService.scanForInactiveCustomers();

        ReactivationCampaign campaign = campaignRepository.findAll().stream()
                .filter(c -> c.getLastVisitBookingId().equals(lastVisitId)).findFirst().orElseThrow();
        assertThat(campaign.getLastVisitAt()).isEqualTo(lastVisit);
        assertThat(campaign.getInactivityDaysAtCreation()).isGreaterThanOrEqualTo(70);
    }

    @Test
    void aPatternedCustomerIsNotFlaggedBeforeTheirPersonalIntervalThreshold() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-early2-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rx-early2-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RX Early2 Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Early2 Service", new BigDecimal("30.00"));

        // Same 35-day cadence (70-day personalized threshold), but only 50
        // days have passed -- past the flat 45-day floor, still short of
        // their own 70-day threshold.
        Instant firstVisit = Instant.now().minus(85, ChronoUnit.DAYS);
        Instant lastVisit = firstVisit.plus(35, ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, firstVisit);
        UUID lastVisitId = createCompletedVisit(owner, customer, providerId, serviceId, lastVisit);

        reactivationDiscoveryService.scanForInactiveCustomers();

        assertThat(campaignRepository.existsByLastVisitBookingId(lastVisitId)).isFalse();
    }

    @Test
    void runningTheScanTwiceForTheSameInactiveCustomerOnlyEverCreatesOneCampaign() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-dup-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rx-dup-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RX Dup Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Dup Service", new BigDecimal("15.00"));

        UUID visitId = createCompletedVisit(owner, customer, providerId, serviceId,
                Instant.now().minus(reactivationProperties.absoluteMaxInactivityDays() + 10, ChronoUnit.DAYS));

        reactivationDiscoveryService.scanForInactiveCustomers();
        // Simulates the next day's sweep re-finding the same still-inactive pair.
        reactivationDiscoveryService.scanForInactiveCustomers();

        long total = campaignRepository.findAll().stream().filter(c -> c.getLastVisitBookingId().equals(visitId))
                .count();
        assertThat(total).isEqualTo(1);
    }

    @Test
    void bookingAgainResolvesTheCampaignAndOutcomeAsRecovered() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-recover-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rx-recover-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RX Recover Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Recover Service", new BigDecimal("55.00"));

        UUID visitId = createCompletedVisit(owner, customer, providerId, serviceId,
                Instant.now().minus(reactivationProperties.absoluteMaxInactivityDays() + 10, ChronoUnit.DAYS));
        reactivationDiscoveryService.scanForInactiveCustomers();

        UUID newSlot = createSlot(owner, providerId, Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID newBookingId = createBooking(customer, providerId, serviceId, newSlot);
        payBooking(customer, newBookingId);

        ReactivationCampaign campaign = campaignRepository.findAll().stream()
                .filter(c -> c.getLastVisitBookingId().equals(visitId)).findFirst().orElseThrow();
        assertThat(campaign.getStatus()).isEqualTo(ReactivationCampaignStatus.BOOKED);
        assertThat(campaign.getRecoveredBookingId()).isEqualTo(newBookingId);

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.CUSTOMER_REACTIVATION, visitId).orElseThrow();
        assertThat(outcome.getRecovered()).isTrue();
        assertThat(outcome.getActualRevenue()).isEqualByComparingTo(new BigDecimal("55.00"));
    }

    @Test
    void noBookingBeforeTheFollowUpWindowClosesExpiresTheCampaignAndOutcome() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-expire-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rx-expire-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RX Expire Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Expire Service", new BigDecimal("22.00"));

        UUID visitId = createCompletedVisit(owner, customer, providerId, serviceId,
                Instant.now().minus(reactivationProperties.absoluteMaxInactivityDays() + 10, ChronoUnit.DAYS));
        reactivationDiscoveryService.scanForInactiveCustomers();
        ReactivationCampaign campaign = campaignRepository.findAll().stream()
                .filter(c -> c.getLastVisitBookingId().equals(visitId)).findFirst().orElseThrow();

        clock.advanceTo(campaign.getExpiresAt().plus(1, ChronoUnit.MINUTES));
        reactivationCampaignService.expireCampaign(campaign.getId(), clock.instant());

        ReactivationCampaign expired = campaignRepository.findById(campaign.getId()).orElseThrow();
        assertThat(expired.getStatus()).isEqualTo(ReactivationCampaignStatus.EXPIRED);

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.CUSTOMER_REACTIVATION, visitId).orElseThrow();
        assertThat(outcome.getRecovered()).isFalse();
        assertThat(outcome.getActualRevenue()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    void revenueEngineSummaryIncludesCustomerReactivationInTheActionTypeBreakdown() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rx-summary-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rx-summary-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RX Summary Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RX Summary Service", new BigDecimal("65.00"));

        createCompletedVisit(owner, customer, providerId, serviceId,
                Instant.now().minus(reactivationProperties.absoluteMaxInactivityDays() + 10, ChronoUnit.DAYS));
        reactivationDiscoveryService.scanForInactiveCustomers();

        UUID newSlot = createSlot(owner, providerId, Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID newBookingId = createBooking(customer, providerId, serviceId, newSlot);
        payBooking(customer, newBookingId);

        ResponseEntity<Map> summary = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/revenue-engine/summary", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(summary.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> byActionType = (Map<?, ?>) summary.getBody().get("recoveredByActionType");
        assertThat(byActionType.get("CUSTOMER_REACTIVATION")).isEqualTo(65.00);
    }

    private UUID createCompletedVisit(Registered owner, Registered customer, UUID providerId, UUID serviceId,
            Instant startsAt) {
        UUID slotId = createSlot(owner, providerId, startsAt, startsAt.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        payBooking(customer, bookingId);
        completeBooking(owner, bookingId);
        return bookingId;
    }

    private void payBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().get("status")).isEqualTo("SUCCEEDED");
    }

    private void completeBooking(Registered owner, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
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
