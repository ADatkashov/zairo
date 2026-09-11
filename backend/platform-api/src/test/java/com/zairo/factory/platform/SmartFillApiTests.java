package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.revenueengine.ActionType;
import com.zairo.factory.revenueengine.RevenueOutcome;
import com.zairo.factory.revenueengine.RevenueOutcomeRepository;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.smartfill.CandidateOffer;
import com.zairo.factory.smartfill.CandidateOfferRepository;
import com.zairo.factory.smartfill.CandidateOfferStatus;
import com.zairo.factory.smartfill.SmartFillCampaign;
import com.zairo.factory.smartfill.SmartFillCampaignRepository;
import com.zairo.factory.smartfill.SmartFillCampaignService;
import com.zairo.factory.smartfill.SmartFillCampaignStatus;
import com.zairo.factory.smartfill.SmartFillProperties;
import com.zairo.factory.smartfill.ScoringFactor;
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
 * End-to-end against a real Postgres (Testcontainers), same style as
 * {@link BookingApiTests}. {@link TestClock} replaces the real system clock
 * so staged-rollout/cooldown timing is driven deterministically instead of
 * waiting on real wall-clock minutes; {@link SmartFillCampaignService}'s
 * job-facing methods are called directly rather than waiting for {@code
 * SmartFillCampaignJob}'s real one-minute cadence -- same "the job is a
 * one-line @Scheduled wrapper, nothing to test there beyond it calls the
 * service" reasoning as {@link SubscriptionRenewalServiceTest}.
 *
 * <p>Every cancellation here goes through {@code revenueengine.DecisionEngine}
 * (Smart Fill is registered as its one {@code RevenueStrategy} today) rather
 * than a direct listener -- these tests exercise that whole path, plus (see
 * the {@code RevenueOutcome}/{@code revenue-engine/summary} tests) the
 * "Revenue Recovered by ZAIRO" ledger it feeds.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestClock.class})
class SmartFillApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

    @Autowired
    private SmartFillCampaignService smartFillCampaignService;

    @Autowired
    private SmartFillCampaignRepository campaignRepository;

    @Autowired
    private CandidateOfferRepository offerRepository;

    @Autowired
    private SmartFillProperties smartFillProperties;

    @Autowired
    private RevenueOutcomeRepository revenueOutcomeRepository;

    @Autowired
    private MutableClock clock;

    /**
     * {@link MutableClock} is one bean shared across every test method in
     * this class's cached Spring context -- without resetting it, an
     * earlier test's {@code advanceTo} would leak into a later test's
     * "now", desyncing it from the real wall-clock timestamps
     * {@code booking.AvailabilitySlot}'s own {@code startsAt} is created
     * with (that part always uses real time, not this test clock).
     */
    @BeforeEach
    void resetClockToRealNow() {
        clock.advanceTo(Instant.now());
    }

    @Test
    void cancellingABookingCreatesASmartFillCampaignForTheFreedSlot() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-create-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "sf-create-customer-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "SF Create Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Create Service", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        cancelBooking(customer, bookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(bookingId).orElseThrow();
        assertThat(campaign.getProviderId()).isEqualTo(providerId);
        assertThat(campaign.getServiceId()).isEqualTo(serviceId);
        assertThat(campaign.getAvailabilitySlotId()).isEqualTo(slotId);
        // No one has ever booked or favorited this brand-new provider except
        // the customer who just cancelled (excluded from their own
        // campaign) -- no eligible candidates, so it expires immediately.
        assertThat(campaign.getStatus()).isEqualTo(SmartFillCampaignStatus.EXPIRED);
    }

    @Test
    void scoresACandidateByAddingUpEveryFactorTheyActuallyMatch() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-score-owner-" + runId + "@example.com");
        Registered candidate = TestAuth.registerCustomer(restTemplate, "sf-score-candidate-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-score-canceller-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "SF Score Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Score Service", new BigDecimal("30.00"));

        // The candidate has booked this exact service with this provider
        // before (in the future, so it isn't a "recent visit" yet) at a
        // fixed time of day far enough from the freed slot's own 15:00 that
        // SUITABLE_HISTORICAL_TIME never coincidentally matches regardless
        // of when this test actually runs.
        Instant earlierStart = Instant.now().plus(10, ChronoUnit.DAYS).truncatedTo(ChronoUnit.DAYS)
                .plus(3, ChronoUnit.HOURS);
        UUID earlierSlot = createSlot(owner, providerId, earlierStart, earlierStart.plus(30, ChronoUnit.MINUTES));
        createBooking(candidate, providerId, serviceId, earlierSlot);

        // A different customer cancels a same-service slot at a very
        // different time of day, freeing it up.
        Instant freedStart = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.DAYS)
                .plus(15, ChronoUnit.HOURS);
        UUID freedSlot = createSlot(owner, providerId, freedStart, freedStart.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, freedSlot);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(cancelledBookingId).orElseThrow();
        List<CandidateOffer> offers = offerRepository.findByCampaignId(campaign.getId());
        CandidateOffer candidateOffer = offers.stream().filter(o -> o.getUserId().equals(candidate.userId()))
                .findFirst().orElseThrow();

        // PREVIOUS_PROVIDER_BOOKING + PREVIOUSLY_BOOKED_SAME_SERVICE always
        // apply here; RECENT_ENGAGEMENT also applies because the candidate's
        // own earlier booking was just created moments ago by this test.
        int expectedScore = smartFillProperties.scoring().weightOf(ScoringFactor.PREVIOUS_PROVIDER_BOOKING)
                + smartFillProperties.scoring().weightOf(ScoringFactor.PREVIOUSLY_BOOKED_SAME_SERVICE)
                + smartFillProperties.scoring().weightOf(ScoringFactor.RECENT_ENGAGEMENT);
        assertThat(candidateOffer.getScore()).isEqualTo(expectedScore);
        assertThat(candidateOffer.getMatchedFactors()).contains("PREVIOUS_PROVIDER_BOOKING",
                "PREVIOUSLY_BOOKED_SAME_SERVICE", "RECENT_ENGAGEMENT");
    }

    @Test
    void aProviderFollowerIsOfferedTheSlotButAWhollyUnrelatedUserIsNot() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-follow-owner-" + runId + "@example.com");
        Registered follower = TestAuth.registerCustomer(restTemplate, "sf-follow-follower-" + runId + "@example.com");
        Registered irrelevant = TestAuth.registerCustomer(restTemplate, "sf-follow-irrelevant-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-follow-canceller-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "SF Follow Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Follow Service", new BigDecimal("25.00"));
        addFavorite(follower, providerId);
        // irrelevant never favorites this provider and never booked it.

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(cancelledBookingId).orElseThrow();
        List<CandidateOffer> offers = offerRepository.findByCampaignId(campaign.getId());

        assertThat(offers).extracting(CandidateOffer::getUserId).containsExactly(follower.userId());
        CandidateOffer followerOffer = offers.get(0);
        assertThat(followerOffer.getScore()).isEqualTo(smartFillProperties.scoring().weightOf(ScoringFactor.FOLLOWS_PROVIDER));
        assertThat(followerOffer.getStatus()).isEqualTo(CandidateOfferStatus.NOTIFIED);
    }

    @Test
    void aPastCustomerIsOfferedTheSlotAheadOfBeingIgnoredEntirely() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-repeat-owner-" + runId + "@example.com");
        Registered repeatCustomer = TestAuth.registerCustomer(restTemplate, "sf-repeat-customer-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-repeat-canceller-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "SF Repeat Salon " + runId);
        UUID serviceA = createService(owner, providerId, "SF Repeat Service A", new BigDecimal("25.00"));
        UUID serviceB = createService(owner, providerId, "SF Repeat Service B", new BigDecimal("40.00"));

        Instant earlierStart = Instant.now().plus(5, ChronoUnit.DAYS);
        UUID earlierSlot = createSlot(owner, providerId, earlierStart, earlierStart.plus(30, ChronoUnit.MINUTES));
        createBooking(repeatCustomer, providerId, serviceA, earlierSlot);

        // A different service is freed up -- repeatCustomer still qualifies
        // via PREVIOUS_PROVIDER_BOOKING (has a relationship with this
        // business), just not PREVIOUSLY_BOOKED_SAME_SERVICE this time.
        Instant freedStart = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID freedSlot = createSlot(owner, providerId, freedStart, freedStart.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceB, freedSlot);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(cancelledBookingId).orElseThrow();
        List<CandidateOffer> offers = offerRepository.findByCampaignId(campaign.getId());

        assertThat(offers).extracting(CandidateOffer::getUserId).containsExactly(repeatCustomer.userId());
        assertThat(offers.get(0).getScore()).isGreaterThan(0);
        assertThat(offers.get(0).getMatchedFactors()).contains("PREVIOUS_PROVIDER_BOOKING");
    }

    @Test
    void aUserRecentlyNotifiedByAnyBusinessIsExcludedFromTheNextCampaignUntilTheCooldownPasses() {
        String runId = UUID.randomUUID().toString();
        Registered ownerA = TestAuth.registerOwner(restTemplate, "sf-cooldown-ownerA-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "sf-cooldown-ownerB-" + runId + "@example.com");
        Registered candidate = TestAuth.registerCustomer(restTemplate, "sf-cooldown-candidate-" + runId + "@example.com");
        Registered cancellerA = TestAuth.registerCustomer(restTemplate, "sf-cooldown-cancellerA-" + runId + "@example.com");
        Registered cancellerB = TestAuth.registerCustomer(restTemplate, "sf-cooldown-cancellerB-" + runId + "@example.com");

        UUID providerA = createProvider(ownerA, "SF Cooldown Salon A " + runId);
        UUID serviceA = createService(ownerA, providerA, "SF Cooldown Service A", new BigDecimal("20.00"));
        addFavorite(candidate, providerA);
        Instant startA = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotA = createSlot(ownerA, providerA, startA, startA.plus(30, ChronoUnit.MINUTES));
        UUID cancelledA = createBooking(cancellerA, providerA, serviceA, slotA);
        cancelBooking(cancellerA, cancelledA);

        SmartFillCampaign campaignA = campaignRepository.findByCancelledBookingId(cancelledA).orElseThrow();
        assertThat(offerRepository.findByCampaignId(campaignA.getId()))
                .extracting(CandidateOffer::getUserId).containsExactly(candidate.userId());

        // The same candidate favorites an entirely different business and a
        // slot frees up there too, well within the per-user cooldown window
        // -- they must not be offered anything a second time yet.
        UUID providerB = createProvider(ownerB, "SF Cooldown Salon B " + runId);
        UUID serviceB = createService(ownerB, providerB, "SF Cooldown Service B", new BigDecimal("20.00"));
        addFavorite(candidate, providerB);
        Instant startB = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotB = createSlot(ownerB, providerB, startB, startB.plus(30, ChronoUnit.MINUTES));
        UUID cancelledB = createBooking(cancellerB, providerB, serviceB, slotB);
        cancelBooking(cancellerB, cancelledB);

        SmartFillCampaign campaignB = campaignRepository.findByCancelledBookingId(cancelledB).orElseThrow();
        assertThat(offerRepository.findByCampaignId(campaignB.getId())).isEmpty();
        assertThat(campaignB.getStatus()).isEqualTo(SmartFillCampaignStatus.EXPIRED);
    }

    @Test
    void notifiesOnlyOneBatchAtATimeThenAdvancesToTheNextStageOnceItsDelayElapses() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-stage-owner-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-stage-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Stage Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Stage Service", new BigDecimal("15.00"));

        int batchSize = smartFillProperties.staging().batchSize();
        int followerCount = batchSize + 1;
        for (int i = 0; i < followerCount; i++) {
            Registered follower = TestAuth.registerCustomer(restTemplate, "sf-stage-follower-" + i + "-" + runId + "@example.com");
            addFavorite(follower, providerId);
        }

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(cancelledBookingId).orElseThrow();
        assertThat(offerRepository.findByCampaignId(campaign.getId())).hasSize(followerCount);
        assertThat(countByStatus(campaign.getId(), CandidateOfferStatus.NOTIFIED)).isEqualTo(batchSize);
        assertThat(countByStatus(campaign.getId(), CandidateOfferStatus.PENDING)).isEqualTo(followerCount - batchSize);
        assertThat(campaign.getStatus()).isEqualTo(SmartFillCampaignStatus.NOTIFYING);

        clock.advanceTo(clock.instant().plus(smartFillProperties.staging().stageDelayMinutes() + 1, ChronoUnit.MINUTES));
        smartFillCampaignService.advanceDueCampaign(campaign.getId(), clock.instant());

        assertThat(countByStatus(campaign.getId(), CandidateOfferStatus.NOTIFIED)).isEqualTo(followerCount);
        assertThat(countByStatus(campaign.getId(), CandidateOfferStatus.PENDING)).isZero();
    }

    @Test
    void aCampaignWithNoBookingBeforeTheSlotStartsExpiresAndClearsOutItsOffers() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-expire-owner-" + runId + "@example.com");
        Registered follower = TestAuth.registerCustomer(restTemplate, "sf-expire-follower-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-expire-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Expire Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Expire Service", new BigDecimal("15.00"));
        addFavorite(follower, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(cancelledBookingId).orElseThrow();
        assertThat(campaign.getStatus()).isEqualTo(SmartFillCampaignStatus.NOTIFYING);

        // Jump past the slot's own start time -- nobody ever booked it.
        clock.advanceTo(start.plus(1, ChronoUnit.MINUTES));
        smartFillCampaignService.advanceDueCampaign(campaign.getId(), clock.instant());

        SmartFillCampaign expired = campaignRepository.findById(campaign.getId()).orElseThrow();
        assertThat(expired.getStatus()).isEqualTo(SmartFillCampaignStatus.EXPIRED);
        assertThat(offerRepository.findByCampaignId(campaign.getId()))
                .allMatch(o -> o.getStatus() == CandidateOfferStatus.EXPIRED);
    }

    @Test
    void bookingByOneCandidateCompletesTheCampaignCancelsTheOtherOfferAndRejectsASecondBookingAttempt() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-win-owner-" + runId + "@example.com");
        Registered winner = TestAuth.registerCustomer(restTemplate, "sf-win-winner-" + runId + "@example.com");
        Registered loser = TestAuth.registerCustomer(restTemplate, "sf-win-loser-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-win-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Win Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Win Service", new BigDecimal("50.00"));
        addFavorite(winner, providerId);
        addFavorite(loser, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(cancelledBookingId).orElseThrow();
        assertThat(offerRepository.findByCampaignId(campaign.getId())).hasSize(2);

        UUID winningBookingId = createBooking(winner, providerId, serviceId, slotId);

        SmartFillCampaign completed = campaignRepository.findById(campaign.getId()).orElseThrow();
        assertThat(completed.getStatus()).isEqualTo(SmartFillCampaignStatus.BOOKED);
        assertThat(completed.getRecoveredBookingId()).isEqualTo(winningBookingId);

        CandidateOffer winnerOffer = offerRepository.findByCampaignId(campaign.getId()).stream()
                .filter(o -> o.getUserId().equals(winner.userId())).findFirst().orElseThrow();
        assertThat(winnerOffer.getStatus()).isEqualTo(CandidateOfferStatus.ACCEPTED);
        assertThat(winnerOffer.getBookingId()).isEqualTo(winningBookingId);

        CandidateOffer loserOffer = offerRepository.findByCampaignId(campaign.getId()).stream()
                .filter(o -> o.getUserId().equals(loser.userId())).findFirst().orElseThrow();
        assertThat(loserOffer.getStatus()).isEqualTo(CandidateOfferStatus.CANCELLED);

        // The slot is BOOKED now -- a second candidate racing for it (or
        // anyone else) is rejected, same guarantee BookingApiTests already
        // proves for the non-Smart-Fill path.
        ResponseEntity<Map> secondAttempt = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateBookingRequest(loser.userId(), serviceId, slotId, new BigDecimal("50.00")),
                        TestAuth.authHeaders(loser.accessToken())),
                Map.class);
        assertThat(secondAttempt.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void recoveredRevenueReflectsTheServicesRealPriceNotAGuessedNumber() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-rev-owner-" + runId + "@example.com");
        Registered winner = TestAuth.registerCustomer(restTemplate, "sf-rev-winner-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-rev-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Revenue Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Revenue Service", new BigDecimal("123.45"));
        addFavorite(winner, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);
        createBooking(winner, providerId, serviceId, slotId);

        ResponseEntity<Map> performance = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/smart-fill/performance", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(performance.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(performance.getBody().get("slotsRecovered")).isEqualTo(1);
        assertThat(performance.getBody().get("recoveredRevenue")).isEqualTo(123.45);
        assertThat(performance.getBody().get("currency")).isEqualTo("USD");
        assertThat(performance.getBody().get("recoveryRate")).isEqualTo(1.0);
    }

    @Test
    void theDecisionEngineRecordsAPendingRevenueOutcomeTheMomentItPicksSmartFill() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-decide-owner-" + runId + "@example.com");
        Registered follower = TestAuth.registerCustomer(restTemplate, "sf-decide-follower-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-decide-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Decide Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Decide Service", new BigDecimal("42.00"));
        addFavorite(follower, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.SMART_FILL, cancelledBookingId).orElseThrow();
        assertThat(outcome.getProviderId()).isEqualTo(providerId);
        assertThat(outcome.getExpectedValue()).isGreaterThan(BigDecimal.ZERO);
        assertThat(outcome.getCurrency()).isEqualTo("USD");
        // Not resolved yet -- the campaign this decision triggered is still running.
        assertThat(outcome.getRecovered()).isNull();
        assertThat(outcome.getActualRevenue()).isNull();
    }

    @Test
    void revenueOutcomeResolvesToRecoveredOnceACandidateBooksTheFreedSlot() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-resolve-owner-" + runId + "@example.com");
        Registered winner = TestAuth.registerCustomer(restTemplate, "sf-resolve-winner-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-resolve-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Resolve Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Resolve Service", new BigDecimal("77.50"));
        addFavorite(winner, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);
        createBooking(winner, providerId, serviceId, slotId);

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.SMART_FILL, cancelledBookingId).orElseThrow();
        assertThat(outcome.getRecovered()).isTrue();
        assertThat(outcome.getActualRevenue()).isEqualByComparingTo(new BigDecimal("77.50"));
        assertThat(outcome.getCurrency()).isEqualTo("USD");
    }

    @Test
    void revenueOutcomeResolvesToNotRecoveredOnceTheCampaignExpiresUnbooked() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-noexpire-owner-" + runId + "@example.com");
        Registered follower = TestAuth.registerCustomer(restTemplate, "sf-noexpire-follower-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-noexpire-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF NoExpire Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF NoExpire Service", new BigDecimal("18.00"));
        addFavorite(follower, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = campaignRepository.findByCancelledBookingId(cancelledBookingId).orElseThrow();
        clock.advanceTo(start.plus(1, ChronoUnit.MINUTES));
        smartFillCampaignService.advanceDueCampaign(campaign.getId(), clock.instant());

        RevenueOutcome outcome = revenueOutcomeRepository
                .findByActionTypeAndTriggerRefId(ActionType.SMART_FILL, cancelledBookingId).orElseThrow();
        assertThat(outcome.getRecovered()).isFalse();
        assertThat(outcome.getActualRevenue()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    void revenueEngineSummaryAggregatesRecoveredRevenueForAProvider() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-summary-owner-" + runId + "@example.com");
        Registered winner = TestAuth.registerCustomer(restTemplate, "sf-summary-winner-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-summary-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Summary Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Summary Service", new BigDecimal("60.00"));
        addFavorite(winner, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);
        createBooking(winner, providerId, serviceId, slotId);

        ResponseEntity<Map> summary = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/revenue-engine/summary", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(summary.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(summary.getBody().get("totalRecovered")).isEqualTo(60.00);
        assertThat(summary.getBody().get("currency")).isEqualTo("USD");
        assertThat(summary.getBody().get("decisionsExecuted")).isEqualTo(1);
        assertThat(summary.getBody().get("decisionsRecovered")).isEqualTo(1);
        Map<?, ?> byActionType = (Map<?, ?>) summary.getBody().get("recoveredByActionType");
        assertThat(byActionType.get("SMART_FILL")).isEqualTo(60.00);
    }

    @Test
    void startingACampaignTwiceForTheSameCancelledBookingOnlyEverCreatesOneCampaign() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sf-dup-owner-" + runId + "@example.com");
        Registered follower = TestAuth.registerCustomer(restTemplate, "sf-dup-follower-" + runId + "@example.com");
        Registered canceller = TestAuth.registerCustomer(restTemplate, "sf-dup-canceller-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "SF Dup Salon " + runId);
        UUID serviceId = createService(owner, providerId, "SF Dup Service", new BigDecimal("15.00"));
        addFavorite(follower, providerId);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(canceller, providerId, serviceId, slotId);
        cancelBooking(canceller, cancelledBookingId);

        // Simulates a duplicated BookingCancelledEvent delivery.
        smartFillCampaignService.startCampaignForCancelledBooking(cancelledBookingId);

        long campaignCount = campaignRepository.findByProviderId(providerId).size();
        assertThat(campaignCount).isEqualTo(1);
    }

    @Test
    void businessOwnersCannotSeeEachOthersSmartFillPerformanceAndCustomersCannotSeeEachOthersOffers() {
        String runId = UUID.randomUUID().toString();
        Registered ownerA = TestAuth.registerOwner(restTemplate, "sf-auth-ownerA-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "sf-auth-ownerB-" + runId + "@example.com");
        Registered customer1 = TestAuth.registerCustomer(restTemplate, "sf-auth-customer1-" + runId + "@example.com");
        Registered customer2 = TestAuth.registerCustomer(restTemplate, "sf-auth-customer2-" + runId + "@example.com");

        UUID providerA = createProvider(ownerA, "SF Auth Salon A " + runId);

        ResponseEntity<Map> crossOwnerAttempt = restTemplate.exchange(
                "/api/v1/providers/" + providerA + "/smart-fill/performance", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(ownerB.accessToken())), Map.class);
        assertThat(crossOwnerAttempt.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Map> crossCustomerAttempt = restTemplate.exchange(
                "/api/v1/users/" + customer1.userId() + "/smart-fill-offers", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer2.accessToken())), Map.class);
        assertThat(crossCustomerAttempt.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    private long countByStatus(UUID campaignId, CandidateOfferStatus status) {
        return offerRepository.findByCampaignId(campaignId).stream().filter(o -> o.getStatus() == status).count();
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

    private void cancelBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private void addFavorite(Registered user, UUID providerId) {
        ResponseEntity<Void> response = restTemplate.exchange(
                "/api/v1/users/" + user.userId() + "/favorites/" + providerId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(user.accessToken())), Void.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }
}
