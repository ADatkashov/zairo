package com.zairo.factory.smartfill;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.staff.Staff;
import com.zairo.factory.staff.StaffRepository;
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

    SmartFillCampaignService(SmartFillCampaignRepository campaignRepository, CandidateOfferRepository offerRepository,
            BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderRepository providerRepository,
            StaffRepository staffRepository, CandidateFinder candidateFinder, NotificationPolicy notificationPolicy,
            ApplicationEventPublisher eventPublisher, SmartFillProperties properties, Clock clock) {
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
    }

    /**
     * {@link BookingCancelledSmartFillListener}'s one call. A no-op if a
     * campaign for this cancellation already exists (duplicate protection --
     * belt-and-braces alongside the unique index) or the freed slot was
     * already re-booked by the time this ran (the event listener's
     * AFTER_COMMIT callback can lag a fast concurrent rebooking) or no
     * eligible candidates exist at all -- the last case still creates the
     * campaign row (for a truthful analytics count of "slots freed") but
     * immediately marks it EXPIRED.
     *
     * <p>{@code REQUIRES_NEW}: called from {@link BookingCancelledSmartFillListener}'s
     * {@code @TransactionalEventListener(phase = AFTER_COMMIT)} callback --
     * see {@code notifications.NotificationService}'s identical doc comment
     * for why a write from inside that callback needs a genuinely new
     * transaction, not one that silently joins the just-completed one.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
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
                        SmartFillCampaignStatus.NOTIFYING));
        Instant now = clock.instant();
        for (SmartFillCampaign campaign : active) {
            campaign.markBooked(bookingId, now);
            campaignRepository.save(campaign);
            closeOutOffers(campaign, bookingId, now);
        }
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
    }
}
