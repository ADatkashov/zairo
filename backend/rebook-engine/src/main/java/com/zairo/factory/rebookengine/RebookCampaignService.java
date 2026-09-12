package com.zairo.factory.rebookengine;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.revenueengine.ActionType;
import com.zairo.factory.revenueengine.RevenueAttributionService;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Owns the {@link RebookCampaign} lifecycle end to end -- the only class
 * that writes to its table. Same transaction-propagation discipline as
 * {@code smartfill.SmartFillCampaignService}: plain {@code @Transactional}
 * when the caller already has an active transaction open ({@link
 * #startCampaignForCompletedBooking} joining {@code
 * revenueengine.DecisionEngine.decideAndExecute}'s {@code REQUIRES_NEW}, or
 * {@link #sendDueOffer}/{@link #expireCampaign} called directly by {@link
 * RebookCampaignJob} with no ambient transaction of their own), {@code
 * REQUIRES_NEW} when called from a raw {@code @TransactionalEventListener(AFTER_COMMIT)}
 * callback that has none ({@link #resolveRebookingsForConfirmedBooking}).
 */
@Service
public class RebookCampaignService {

    private final RebookCampaignRepository campaignRepository;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final RevenueAttributionService revenueAttributionService;
    private final ApplicationEventPublisher eventPublisher;
    private final RebookProperties properties;
    private final Clock clock;

    RebookCampaignService(RebookCampaignRepository campaignRepository, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository, RevenueAttributionService revenueAttributionService,
            ApplicationEventPublisher eventPublisher, RebookProperties properties, Clock clock) {
        this.campaignRepository = campaignRepository;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.revenueAttributionService = revenueAttributionService;
        this.eventPublisher = eventPublisher;
        this.properties = properties;
        this.clock = clock;
    }

    /**
     * {@link RebookStrategy#execute}'s one call, made when the Decision
     * Engine picks {@code REBOOK} for a {@code BOOKING_COMPLETED} decision.
     * A no-op if a campaign for this completion already exists (duplicate
     * protection, belt-and-braces alongside the unique index), the booking/
     * slot no longer resolve, or the visit history turns out too thin once
     * actually fetched (the strategy's {@code evaluate} already checked
     * this, but re-checking here costs nothing and stays correct even if
     * this method is ever called from somewhere else).
     */
    @Transactional
    public void startCampaignForCompletedBooking(UUID completedBookingId) {
        if (campaignRepository.existsByCompletedBookingId(completedBookingId)) {
            return;
        }
        Booking completedBooking = bookingRepository.findById(completedBookingId).orElse(null);
        if (completedBooking == null) {
            return;
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(completedBooking.getAvailabilitySlotId())
                .orElse(null);
        if (slot == null) {
            return;
        }

        List<Booking> visitHistory = bookingRepository
                .findCompletedByUserIdAndProviderIdOrderByVisitDate(completedBooking.getUserId(), slot.getProviderId());
        if (visitHistory.size() < properties.minVisitsToEstablishInterval()) {
            return;
        }

        Map<UUID, Instant> slotStartTimes = availabilitySlotRepository
                .findAllById(visitHistory.stream().map(Booking::getAvailabilitySlotId).toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, AvailabilitySlot::getStartsAt));
        List<Instant> visitTimes = visitHistory.stream().map(b -> slotStartTimes.get(b.getAvailabilitySlotId()))
                .filter(Objects::nonNull).sorted().toList();
        if (visitTimes.size() < properties.minVisitsToEstablishInterval()) {
            return;
        }

        int averageIntervalDays = computeAverageIntervalDays(visitTimes);
        Instant lastVisitAt = visitTimes.get(visitTimes.size() - 1);
        Instant now = clock.instant();
        Instant dueAt = lastVisitAt.plus(averageIntervalDays, ChronoUnit.DAYS);
        Instant expiresAt = dueAt.plus(properties.followUpWindowDays(), ChronoUnit.DAYS);

        RebookCampaign campaign = new RebookCampaign(UUID.randomUUID(), slot.getProviderId(),
                completedBooking.getServiceId(), completedBooking.getUserId(), completedBookingId, lastVisitAt,
                averageIntervalDays, dueAt, expiresAt, completedBooking.getTotalPrice(),
                completedBooking.getCurrency(), now);
        campaignRepository.save(campaign);
    }

    /** {@link RebookCampaignJob}'s sweep target for a CREATED campaign whose predicted next-visit date has arrived. */
    @Transactional
    public void sendDueOffer(UUID campaignId, Instant now) {
        RebookCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || campaign.getStatus() != RebookCampaignStatus.CREATED) {
            return;
        }
        String providerName = providerRepository.findById(campaign.getProviderId()).map(Provider::getName)
                .orElse(null);
        String serviceName = serviceOfferingRepository.findById(campaign.getServiceId()).map(ServiceOffering::getTitle)
                .orElse(null);

        campaign.markOffered(now);
        campaignRepository.save(campaign);
        eventPublisher.publishEvent(new RebookOfferReadyEvent(campaign.getId(), campaign.getUserId(),
                campaign.getProviderId(), providerName, serviceName));
    }

    /** {@link RebookCampaignJob}'s sweep target for an OFFERED campaign whose follow-up window has closed unbooked. */
    @Transactional
    public void expireCampaign(UUID campaignId, Instant now) {
        RebookCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.isActive()) {
            return;
        }
        campaign.markExpired(now);
        campaignRepository.save(campaign);
        revenueAttributionService.resolve(ActionType.REBOOK, campaign.getCompletedBookingId(), BigDecimal.ZERO,
                campaign.getPriceCurrency(), false, now);
    }

    /**
     * {@link RebookOutcomeListener}'s one call, fired whenever ANY booking
     * is confirmed -- closes out every still-active campaign for this exact
     * customer+provider pair as a genuine "they came back" win, whether or
     * not they ever saw/clicked the nudge (a customer who books again on
     * their own initiative before the nudge even goes out is still a win,
     * just an organic one). {@code REQUIRES_NEW}: called from a raw {@code
     * @TransactionalEventListener(AFTER_COMMIT)} callback with no active
     * transaction of its own -- same reasoning as {@code
     * smartfill.SmartFillCampaignService#completeCampaignsForBookedSlot}.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void resolveRebookingsForConfirmedBooking(UUID userId, UUID providerId, UUID newBookingId, Instant now) {
        List<RebookCampaign> active = campaignRepository.findByUserIdAndProviderIdAndStatusIn(userId, providerId,
                List.of(RebookCampaignStatus.CREATED, RebookCampaignStatus.OFFERED));
        if (active.isEmpty()) {
            return;
        }
        Booking newBooking = bookingRepository.findById(newBookingId).orElse(null);
        BigDecimal actualRevenue = newBooking == null ? BigDecimal.ZERO : newBooking.getTotalPrice();
        for (RebookCampaign campaign : active) {
            campaign.markBooked(newBookingId, now);
            campaignRepository.save(campaign);
            String currency = newBooking == null ? campaign.getPriceCurrency() : newBooking.getCurrency();
            revenueAttributionService.resolve(ActionType.REBOOK, campaign.getCompletedBookingId(), actualRevenue,
                    currency, true, now);
        }
    }

    /**
     * The average gap (in days) between consecutive visits, oldest to
     * newest, clamped to {@link RebookProperties}' sane range -- a single
     * outlier (a customer who vanished for a year then came back once)
     * shouldn't predict an absurd cadence for everyone after them.
     */
    private int computeAverageIntervalDays(List<Instant> visitTimes) {
        long totalDays = 0;
        int gaps = visitTimes.size() - 1;
        for (int i = 1; i < visitTimes.size(); i++) {
            totalDays += Duration.between(visitTimes.get(i - 1), visitTimes.get(i)).toDays();
        }
        long averageGapDays = gaps == 0 ? properties.minIntervalDays() : totalDays / gaps;
        return properties.clamp(averageGapDays);
    }
}
