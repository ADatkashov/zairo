package com.zairo.factory.smartfill;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.revenueengine.ActionType;
import com.zairo.factory.revenueengine.RevenueAttributionService;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.staff.Staff;
import com.zairo.factory.staff.StaffRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Owns the {@link SmartFillCampaign}/{@link CandidateOffer} lifecycle end to
 * end -- the only class that writes to either table. Every public method is
 * its own transaction; {@code @Version} on both entities means a losing
 * writer (two job runs racing the same campaign, or a job run racing a
 * same-slot booking's close-out) gets an {@code OptimisticLockingFailureException}
 * and simply rolls back rather than double-processing -- callers ({@link
 * SmartFillCampaignJob}, the event listeners) catch that and move on, same
 * pattern as {@code booking.BookingPaymentTimeoutJob}. Rolling back also
 * means the {@link SmartFillOfferReadyEvent}s this method would have
 * published never actually fire (they're plain {@code
 * ApplicationEventPublisher} events, delivered to {@code
 * @TransactionalEventListener(phase = AFTER_COMMIT)} consumers only once
 * this transaction actually commits) -- the losing writer never sends a
 * duplicate notification, without any extra locking beyond the version
 * check itself.
 */
@Service
public class SmartFillCampaignService {

    private final SmartFillCampaignRepository campaignRepository;
    private final CandidateOfferRepository offerRepository;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderRepository providerRepository;
    private final StaffRepository staffRepository;
    private final CandidateFinder candidateFinder;
    private final NotificationPolicy notificationPolicy;
    private final ApplicationEventPublisher eventPublisher;
    private final SmartFillProperties properties;
    private final Clock clock;
    private final RevenueAttributionService revenueAttributionService;

    SmartFillCampaignService(SmartFillCampaignRepository campaignRepository, CandidateOfferRepository offerRepository,
            BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderRepository providerRepository,
            StaffRepository staffRepository, CandidateFinder candidateFinder, NotificationPolicy notificationPolicy,
            ApplicationEventPublisher eventPublisher, SmartFillProperties properties, Clock clock,
            RevenueAttributionService revenueAttributionService) {
        this.campaignRepository = campaignRepository;
        this.offerRepository = offerRepository;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerRepository = providerRepository;
        this.staffRepository = staffRepository;
        this.candidateFinder = candidateFinder;
        this.notificationPolicy = notificationPolicy;
        this.eventPublisher = eventPublisher;
        this.properties = properties;
        this.clock = clock;
        this.revenueAttributionService = revenueAttributionService;
    }

    /**
     * {@link SmartFillStrategy#execute}'s one call, made when the Decision
     * Engine picks {@code SMART_FILL} for a {@code BOOKING_CANCELLED}
     * decision -- see {@code revenueengine}'s package-info for the full
     * flow. A no-op if a campaign for this cancellation already exists
     * (duplicate protection -- belt-and-braces alongside the unique index)
     * or the freed slot was already re-booked by the time this ran (the
     * strategy's own {@code evaluate} already re-checks this, but the
     * window between evaluate and execute is real) or no eligible
     * candidates exist at all -- the last case still creates the campaign
     * row (for a truthful analytics count of "slots freed") but immediately
     * marks it EXPIRED.
     *
     * <p>Plain {@code @Transactional} (not {@code REQUIRES_NEW}): unlike
     * {@link #completeCampaignsForBookedSlot}, this always runs with an
     * active transaction already open -- either {@code
     * revenueengine.DecisionEngine.decideAndExecute}'s own {@code
     * REQUIRES_NEW} transaction (so this joins it, making the recorded
     * decision and the campaign it creates commit or roll back together),
     * or a caller's own transaction in tests. No transaction is ever
     * "just completed" at this call site the way {@code
     * notifications.NotificationService}'s {@code REQUIRES_NEW} methods
     * guard against.
     */
    @Transactional
    public void startCampaignForCancelledBooking(UUID cancelledBookingId) {
        if (campaignRepository.existsByCancelledBookingId(cancelledBookingId)) {
            return;
        }
        Booking cancelledBooking = bookingRepository.findById(cancelledBookingId).orElse(null);
        if (cancelledBooking == null) {
            return;
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(cancelledBooking.getAvailabilitySlotId())
                .orElse(null);
        if (slot == null || slot.getStatus() != AvailabilityStatus.OPEN) {
            return;
        }
        ServiceOffering service = serviceOfferingRepository.findById(cancelledBooking.getServiceId()).orElse(null);
        if (service == null) {
            return;
        }

        Instant now = clock.instant();
        SmartFillCampaign campaign = new SmartFillCampaign(UUID.randomUUID(), slot.getProviderId(), service.getId(),
                slot.getEmployeeId(), slot.getId(), cancelledBookingId, slot.getStartsAt(), slot.getEndsAt(),
                service.getPrice(), service.getCurrency(), now);
        campaign = campaignRepository.save(campaign);

        List<ScoredCandidate> candidates = candidateFinder.findCandidates(campaign, cancelledBooking.getUserId(), now);
        if (candidates.isEmpty()) {
            expireCampaign(campaign, now);
            return;
        }

        int batchSize = Math.max(1, properties.staging().batchSize());
        List<CandidateOffer> offers = new ArrayList<>(candidates.size());
        for (int i = 0; i < candidates.size(); i++) {
            ScoredCandidate candidate = candidates.get(i);
            offers.add(new CandidateOffer(UUID.randomUUID(), campaign.getId(), campaign.getProviderId(),
                    candidate.userId(), candidate.score(), i + 1, i / batchSize, candidate.matchedFactors(), now));
        }
        offerRepository.saveAll(offers);
        campaign.markSearching();
        campaignRepository.save(campaign);

        sendStage(campaign, 0, offerRepository.findByCampaignIdAndStage(campaign.getId(), 0), now);
    }

    /** {@link SmartFillCampaignJob}'s one call for a campaign whose {@code nextStageAt} is due. */
    @Transactional
    public void advanceDueCampaign(UUID campaignId, Instant now) {
        SmartFillCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.isActive()) {
            return;
        }

        AvailabilitySlot slot = availabilitySlotRepository.findById(campaign.getAvailabilitySlotId()).orElse(null);
        if (slot == null || slot.getStatus() != AvailabilityStatus.OPEN) {
            // The AvailabilitySlotBookedEvent listener should already have
            // closed this out -- this is a defensive fallback, not the
            // normal path (see this class's own doc comment).
            resolveAndCloseAsBooked(campaign, now);
            return;
        }

        boolean pastSlotStart = !now.isBefore(campaign.getSlotStartsAt());
        boolean pastMaxDuration = now.isAfter(
                campaign.getCreatedAt().plus(properties.staging().campaignMaxDurationMinutes(), ChronoUnit.MINUTES));
        int nextStage = campaign.getCurrentStage() + 1;
        List<CandidateOffer> stageOffers = offerRepository.findByCampaignIdAndStage(campaign.getId(), nextStage);

        if (pastSlotStart || pastMaxDuration || stageOffers.isEmpty() || nextStage >= properties.staging().maxStages()) {
            expireCampaign(campaign, now);
            return;
        }
        sendStage(campaign, nextStage, stageOffers, now);
    }

    /**
     * {@link SlotBookedSmartFillListener}'s one call, fired the instant
     * {@code booking.AvailabilitySlotBookedEvent} lands for this slot --
     * whether the booking came from one of this campaign's own candidates
     * or a completely unrelated customer who found the slot another way.
     * Every campaign still active for this slot is closed: its own
     * candidate's offer (if any) becomes ACCEPTED, everyone else's pending
     * offer becomes CANCELLED, and no further stage is ever sent (checked
     * via {@link SmartFillCampaign#isActive()} in {@link #advanceDueCampaign}).
     *
     * <p>{@code REQUIRES_NEW}: called from {@link SlotBookedSmartFillListener}'s
     * {@code @TransactionalEventListener(phase = AFTER_COMMIT)} callback --
     * same reasoning as {@link #startCampaignForCancelledBooking}.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void completeCampaignsForBookedSlot(UUID availabilitySlotId, UUID bookingId) {
        List<SmartFillCampaign> active = campaignRepository.findByAvailabilitySlotIdAndStatusIn(availabilitySlotId,
                List.of(SmartFillCampaignStatus.CREATED, SmartFillCampaignStatus.SEARCHING,
                        SmartFillCampaignStatus.NOTIFYING, SmartFillCampaignStatus.PAUSED));
        Instant now = clock.instant();
        for (SmartFillCampaign campaign : active) {
            campaign.markBooked(bookingId, now);
            campaignRepository.save(campaign);
            closeOutOffers(campaign, bookingId, now);
            resolveRevenueOutcome(campaign, bookingId, now);
        }
    }

    /**
     * {@code campaigncenter.CampaignCenterService}'s pause action -- only
     * meaningful while a stage is actively out (NOTIFYING); CREATED/SEARCHING
     * are same-transaction transients (see {@link SmartFillCampaignStatus}'s
     * own doc comment) not worth exposing an owner-facing pause for. Returns
     * false (a no-op, not an error) if the campaign isn't in a pausable state
     * -- idempotent under a retried/duplicate request.
     */
    @Transactional
    public boolean pauseCampaign(UUID campaignId) {
        SmartFillCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || campaign.getStatus() != SmartFillCampaignStatus.NOTIFYING) {
            return false;
        }
        campaign.markPaused();
        campaignRepository.save(campaign);
        return true;
    }

    /**
     * {@code campaigncenter.CampaignCenterService}'s resume action --
     * schedules the next stage as if the paused stage had just been sent,
     * same delay as a normal stage transition. False (no-op) if the campaign
     * isn't currently paused.
     */
    @Transactional
    public boolean resumeCampaign(UUID campaignId, Instant now) {
        SmartFillCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || campaign.getStatus() != SmartFillCampaignStatus.PAUSED) {
            return false;
        }
        Instant nextStageAt = now.plus(properties.staging().stageDelayMinutes(), ChronoUnit.MINUTES);
        campaign.markResumed(nextStageAt);
        campaignRepository.save(campaign);
        return true;
    }

    /**
     * {@code campaigncenter.CampaignCenterService}'s cancel action -- an
     * owner-initiated abort, same close-out as {@link #expireCampaign}
     * (every still-open offer becomes CANCELLED, the outcome ledger resolves
     * to not-recovered) but reachable from PAUSED too, not just active
     * staging. False (no-op) once the campaign is already terminal (BOOKED/
     * EXPIRED/CANCELLED) -- idempotent under a retried/duplicate request.
     */
    @Transactional
    public boolean cancelCampaign(UUID campaignId, Instant now) {
        SmartFillCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !(campaign.isActive() || campaign.getStatus() == SmartFillCampaignStatus.PAUSED)) {
            return false;
        }
        campaign.markCancelled(now);
        campaignRepository.save(campaign);
        closeOutOffers(campaign, null, now);
        revenueAttributionService.resolve(ActionType.SMART_FILL, campaign.getCancelledBookingId(), BigDecimal.ZERO,
                campaign.getPriceCurrency(), false, now);
        return true;
    }

    /**
     * {@code campaigncenter.CampaignCenterService}'s retry action -- only for
     * a campaign that expired never having recovered its slot, and whose
     * slot is still genuinely OPEN (not booked by someone else since). Runs
     * the exact same candidate-discovery-and-first-stage flow {@link
     * #startCampaignForCancelledBooking} does, on the same campaign row
     * (own new stage numbers, continuing on from wherever staging left off)
     * rather than creating a second campaign for the same cancellation.
     * False (no-op, not an error) if the campaign isn't retriable or no
     * eligible candidates exist right now -- idempotent under a retried/
     * duplicate request, and safe to call on an already-active campaign
     * (returns false rather than sending a duplicate round of notifications).
     */
    @Transactional
    public boolean retryCampaign(UUID campaignId, Instant now) {
        SmartFillCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || campaign.getStatus() != SmartFillCampaignStatus.EXPIRED
                || campaign.getRecoveredBookingId() != null) {
            return false;
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(campaign.getAvailabilitySlotId()).orElse(null);
        if (slot == null || slot.getStatus() != AvailabilityStatus.OPEN) {
            return false;
        }
        Booking cancelledBooking = bookingRepository.findById(campaign.getCancelledBookingId()).orElse(null);
        UUID excludedUserId = cancelledBooking == null ? null : cancelledBooking.getUserId();

        List<ScoredCandidate> candidates = candidateFinder.findCandidates(campaign, excludedUserId, now);
        if (candidates.isEmpty()) {
            return false;
        }

        int nextStage = campaign.getCurrentStage() + 1;
        int batchSize = Math.max(1, properties.staging().batchSize());
        List<CandidateOffer> offers = new ArrayList<>(candidates.size());
        for (int i = 0; i < candidates.size(); i++) {
            ScoredCandidate candidate = candidates.get(i);
            offers.add(new CandidateOffer(UUID.randomUUID(), campaign.getId(), campaign.getProviderId(),
                    candidate.userId(), candidate.score(), i + 1, nextStage + i / batchSize, candidate.matchedFactors(),
                    now));
        }
        offerRepository.saveAll(offers);
        campaign.markSearching();
        campaignRepository.save(campaign);

        sendStage(campaign, nextStage, offerRepository.findByCampaignIdAndStage(campaign.getId(), nextStage), now);
        return true;
    }

    private void sendStage(SmartFillCampaign campaign, int stage, List<CandidateOffer> stageOffers, Instant now) {
        Provider provider = providerRepository.findById(campaign.getProviderId()).orElse(null);
        ServiceOffering service = serviceOfferingRepository.findById(campaign.getServiceId()).orElse(null);
        String employeeName = campaign.getEmployeeId() == null ? null
                : staffRepository.findById(campaign.getEmployeeId()).map(Staff::getDisplayName).orElse(null);

        Instant nextStageAt = now.plus(properties.staging().stageDelayMinutes(), ChronoUnit.MINUTES);
        campaign.markStageSent(stage, nextStageAt);
        campaignRepository.save(campaign);

        for (CandidateOffer offer : stageOffers) {
            // Re-checked here, not just at pool-build time: limits/cooldowns
            // are a moving target between a campaign's creation and a later
            // stage sent minutes afterward (see NotificationPolicy's doc
            // comment). A candidate that fails this now simply never gets
            // notified -- it's swept up as CANCELLED/EXPIRED whenever the
            // campaign resolves, same as any other un-notified offer.
            if (!notificationPolicy.mayOffer(offer.getUserId(), campaign.getProviderId(), now)) {
                continue;
            }
            offer.markNotified(now);
            offerRepository.save(offer);
            eventPublisher.publishEvent(new SmartFillOfferReadyEvent(offer.getId(), campaign.getId(),
                    offer.getUserId(), campaign.getProviderId(), provider == null ? null : provider.getName(),
                    service == null ? null : service.getTitle(), employeeName, campaign.getSlotStartsAt(),
                    campaign.getSlotEndsAt()));
        }
    }

    private void resolveAndCloseAsBooked(SmartFillCampaign campaign, Instant now) {
        UUID bookingId = bookingRepository.findByAvailabilitySlotIdIn(List.of(campaign.getAvailabilitySlotId()))
                .stream()
                .filter(b -> b.getStatus() != BookingStatus.CANCELLED)
                .max(Comparator.comparing(Booking::getCreatedAt))
                .map(Booking::getId)
                .orElse(null);
        campaign.markBooked(bookingId, now);
        campaignRepository.save(campaign);
        closeOutOffers(campaign, bookingId, now);
        resolveRevenueOutcome(campaign, bookingId, now);
    }

    /**
     * Reports the campaign's real outcome back to the Decision Engine's
     * ledger -- {@link RevenueAttributionService#recordDecision} already
     * wrote a pending row for this cancellation when the engine chose
     * SMART_FILL; this fills in what actually happened. {@code bookingId}
     * null (the {@link #resolveAndCloseAsBooked} fallback couldn't find an
     * active booking for the slot) leaves the outcome pending rather than
     * guessing -- an honest "don't know" beats a wrong number in the
     * revenue-recovered ledger.
     */
    private void resolveRevenueOutcome(SmartFillCampaign campaign, UUID bookingId, Instant now) {
        if (bookingId == null) {
            return;
        }
        Booking recoveredBooking = bookingRepository.findById(bookingId).orElse(null);
        BigDecimal actualRevenue = recoveredBooking == null ? BigDecimal.ZERO : recoveredBooking.getTotalPrice();
        String currency = recoveredBooking == null ? campaign.getPriceCurrency() : recoveredBooking.getCurrency();
        revenueAttributionService.resolve(ActionType.SMART_FILL, campaign.getCancelledBookingId(), actualRevenue,
                currency, true, now);
    }

    private void closeOutOffers(SmartFillCampaign campaign, UUID recoveredBookingId, Instant now) {
        UUID winningUserId = recoveredBookingId == null ? null
                : bookingRepository.findById(recoveredBookingId).map(Booking::getUserId).orElse(null);
        List<CandidateOffer> offers = offerRepository.findByCampaignIdAndStatusIn(campaign.getId(),
                List.of(CandidateOfferStatus.PENDING, CandidateOfferStatus.NOTIFIED, CandidateOfferStatus.VIEWED));
        for (CandidateOffer offer : offers) {
            if (winningUserId != null && offer.getUserId().equals(winningUserId)) {
                offer.markAccepted(recoveredBookingId, now);
            } else {
                offer.markCancelled();
            }
            offerRepository.save(offer);
        }
    }

    private void expireCampaign(SmartFillCampaign campaign, Instant now) {
        campaign.markExpired(now);
        campaignRepository.save(campaign);
        List<CandidateOffer> offers = offerRepository.findByCampaignIdAndStatusIn(campaign.getId(),
                List.of(CandidateOfferStatus.PENDING, CandidateOfferStatus.NOTIFIED, CandidateOfferStatus.VIEWED));
        for (CandidateOffer offer : offers) {
            offer.markExpired();
            offerRepository.save(offer);
        }
        revenueAttributionService.resolve(ActionType.SMART_FILL, campaign.getCancelledBookingId(), BigDecimal.ZERO,
                campaign.getPriceCurrency(), false, now);
    }
}
