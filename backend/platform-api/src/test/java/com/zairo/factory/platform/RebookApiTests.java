package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.rebookengine.RebookCampaign;
import com.zairo.factory.rebookengine.RebookCampaignRepository;
import com.zairo.factory.rebookengine.RebookCampaignService;
import com.zairo.factory.rebookengine.RebookCampaignStatus;
import com.zairo.factory.rebookengine.RebookProperties;
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
 * SmartFillApiTests}. {@link TestClock} replaces the real system clock for
 * job-facing timing; {@link RebookCampaignService}'s job-facing methods are
 * called directly rather than waiting for {@code RebookCampaignJob}'s real
 * hourly cadence -- same "the job is a one-line @Scheduled wrapper" reasoning
 * {@code SmartFillApiTests} already documents. Visit timestamps themselves
 * use real wall-clock time (via {@code Instant.now()}), not the mutable
 * clock, so the average-interval math stays independent of whatever the
 * clock happens to be set to at that point in a given test.
 *
 * <p>Every completion here goes through {@code revenueengine.DecisionEngine}
 * (Rebook is registered as one of its {@code RevenueStrategy}s) rather than
 * a direct listener, exercising the whole path plus the shared "Revenue
 * Recovered by ZAIRO" ledger it feeds.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestClock.class})
class RebookApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

    @Autowired
    private RebookCampaignService rebookCampaignService;

    @Autowired
    private RebookCampaignRepository campaignRepository;

    @Autowired
    private RebookProperties rebookProperties;

    @Autowired
    private RevenueOutcomeRepository revenueOutcomeRepository;

    @Autowired
    private MutableClock clock;

    @BeforeEach
    void resetClockToRealNow() {
        clock.advanceTo(Instant.now());
    }

    @Test
    void completingASecondVisitCreatesARebookCampaignDueOnThePredictedNextVisitDate() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-create-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rb-create-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RB Create Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB Create Service", new BigDecimal("50.00"));

        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(40, ChronoUnit.DAYS));
        UUID secondVisitId = createCompletedVisit(owner, customer, providerId, serviceId,
                today.minus(10, ChronoUnit.DAYS));

        RebookCampaign campaign = campaignRepository.findByCompletedBookingId(secondVisitId).orElseThrow();
        assertThat(campaign.getProviderId()).isEqualTo(providerId);
        assertThat(campaign.getServiceId()).isEqualTo(serviceId);
        assertThat(campaign.getUserId()).isEqualTo(customer.userId());
        assertThat(campaign.getStatus()).isEqualTo(RebookCampaignStatus.CREATED);
        // Exactly 30 days between the two visits, well within the configured range.
        assertThat(campaign.getAverageIntervalDays()).isEqualTo(30);
        assertThat(campaign.getLastVisitAt()).isEqualTo(today.minus(10, ChronoUnit.DAYS));
        assertThat(campaign.getDueAt()).isEqualTo(today.minus(10, ChronoUnit.DAYS).plus(30, ChronoUnit.DAYS));
        assertThat(campaign.getExpiresAt())
                .isEqualTo(campaign.getDueAt().plus(rebookProperties.followUpWindowDays(), ChronoUnit.DAYS));
    }

    @Test
    void aSingleVisitIsNotEnoughHistoryToCreateARebookCampaign() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-onevisit-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rb-onevisit-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RB OneVisit Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB OneVisit Service", new BigDecimal("25.00"));

        UUID firstVisitId = createCompletedVisit(owner, customer, providerId, serviceId,
                Instant.now().minus(1, ChronoUnit.DAYS));

        assertThat(campaignRepository.findByCompletedBookingId(firstVisitId)).isEmpty();
        assertThat(revenueOutcomeRepository.findByActionTypeAndTriggerRefId(ActionType.REBOOK, firstVisitId))
                .isEmpty();
    }

    @Test
    void theDecisionEngineRecordsAPendingRevenueOutcomeTheMomentItPicksRebook() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-pending-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rb-pending-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RB Pending Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB Pending Service", new BigDecimal("65.00"));

        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(60, ChronoUnit.DAYS));
        UUID secondVisitId = createCompletedVisit(owner, customer, providerId, serviceId,
                today.minus(20, ChronoUnit.DAYS));

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.REBOOK, secondVisitId).orElseThrow();
        assertThat(outcome.getProviderId()).isEqualTo(providerId);
        assertThat(outcome.getExpectedValue()).isEqualByComparingTo(new BigDecimal("65.00"));
        assertThat(outcome.getCurrency()).isEqualTo("USD");
        assertThat(outcome.getRecovered()).isNull();
        assertThat(outcome.getActualRevenue()).isNull();
    }

    @Test
    void sendingTheDueOfferEmailsTheCustomerAndMarksTheCampaignOffered() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-offer-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rb-offer-customer-" + runId + "@example.com");
        String customerEmail = "rb-offer-customer-" + runId + "@example.com";
        UUID providerId = createProvider(owner, "RB Offer Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB Offer Service", new BigDecimal("35.00"));

        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(50, ChronoUnit.DAYS));
        UUID secondVisitId = createCompletedVisit(owner, customer, providerId, serviceId,
                today.minus(20, ChronoUnit.DAYS));
        RebookCampaign campaign = campaignRepository.findByCompletedBookingId(secondVisitId).orElseThrow();

        clock.advanceTo(campaign.getDueAt().plus(1, ChronoUnit.MINUTES));
        rebookCampaignService.sendDueOffer(campaign.getId(), clock.instant());

        RebookCampaign offered = campaignRepository.findById(campaign.getId()).orElseThrow();
        assertThat(offered.getStatus()).isEqualTo(RebookCampaignStatus.OFFERED);
        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(customerEmail);
            assertThat(email.body()).contains("RB Offer Service").contains("RB Offer Salon " + runId);
        });
    }

    @Test
    void rebookingWithTheSameProviderResolvesTheCampaignAndOutcomeAsRecovered() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-recover-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rb-recover-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RB Recover Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB Recover Service", new BigDecimal("42.00"));

        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(50, ChronoUnit.DAYS));
        UUID secondVisitId = createCompletedVisit(owner, customer, providerId, serviceId,
                today.minus(20, ChronoUnit.DAYS));

        // The customer books again on their own initiative, before the nudge
        // was ever due -- still a genuine win (see RebookCampaignService's
        // own doc comment on resolveRebookingsForConfirmedBooking).
        UUID newSlot = createSlot(owner, providerId, Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID newBookingId = createBooking(customer, providerId, serviceId, newSlot);
        payBooking(customer, newBookingId);

        RebookCampaign campaign = campaignRepository.findByCompletedBookingId(secondVisitId).orElseThrow();
        assertThat(campaign.getStatus()).isEqualTo(RebookCampaignStatus.BOOKED);
        assertThat(campaign.getRecoveredBookingId()).isEqualTo(newBookingId);

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.REBOOK, secondVisitId).orElseThrow();
        assertThat(outcome.getRecovered()).isTrue();
        assertThat(outcome.getActualRevenue()).isEqualByComparingTo(new BigDecimal("42.00"));
    }

    @Test
    void noRebookingBeforeTheFollowUpWindowClosesExpiresTheCampaignAndOutcome() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-expire-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rb-expire-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RB Expire Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB Expire Service", new BigDecimal("28.00"));

        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(50, ChronoUnit.DAYS));
        UUID secondVisitId = createCompletedVisit(owner, customer, providerId, serviceId,
                today.minus(20, ChronoUnit.DAYS));
        RebookCampaign campaign = campaignRepository.findByCompletedBookingId(secondVisitId).orElseThrow();

        clock.advanceTo(campaign.getExpiresAt().plus(1, ChronoUnit.MINUTES));
        rebookCampaignService.expireCampaign(campaign.getId(), clock.instant());

        RebookCampaign expired = campaignRepository.findById(campaign.getId()).orElseThrow();
        assertThat(expired.getStatus()).isEqualTo(RebookCampaignStatus.EXPIRED);

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.REBOOK, secondVisitId).orElseThrow();
        assertThat(outcome.getRecovered()).isFalse();
        assertThat(outcome.getActualRevenue()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    void startingACampaignTwiceForTheSameCompletedBookingOnlyEverCreatesOne() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-dup-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rb-dup-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RB Dup Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB Dup Service", new BigDecimal("15.00"));

        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(50, ChronoUnit.DAYS));
        UUID secondVisitId = createCompletedVisit(owner, customer, providerId, serviceId,
                today.minus(20, ChronoUnit.DAYS));

        // Simulates a duplicated BookingCompletedEvent delivery.
        rebookCampaignService.startCampaignForCompletedBooking(secondVisitId);

        long total = campaignRepository.findAll().stream()
                .filter(c -> c.getCompletedBookingId().equals(secondVisitId)).count();
        assertThat(total).isEqualTo(1);
    }

    @Test
    void revenueEngineSummaryIncludesRebookInTheActionTypeBreakdown() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "rb-summary-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rb-summary-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "RB Summary Salon " + runId);
        UUID serviceId = createService(owner, providerId, "RB Summary Service", new BigDecimal("55.00"));

        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(50, ChronoUnit.DAYS));
        createCompletedVisit(owner, customer, providerId, serviceId, today.minus(20, ChronoUnit.DAYS));

        UUID newSlot = createSlot(owner, providerId, Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID newBookingId = createBooking(customer, providerId, serviceId, newSlot);
        payBooking(customer, newBookingId);

        ResponseEntity<Map> summary = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/revenue-engine/summary", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(summary.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> byActionType = (Map<?, ?>) summary.getBody().get("recoveredByActionType");
        assertThat(byActionType.get("REBOOK")).isEqualTo(55.00);
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
