package com.zairo.factory.reactivationengine;

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
 * Owns the {@link ReactivationCampaign} lifecycle end to end -- the only
 * class that writes to its table. Same transaction-propagation discipline
 * as {@code rebookengine.RebookCampaignService}: plain {@code @Transactional}
 * when the caller already has an active transaction open ({@link
 * #startCampaignForInactiveCustomer} joining {@code
 * revenueengine.DecisionEngine.decideAndExecute}'s {@code REQUIRES_NEW}, or
 * {@link #expireCampaign} called directly by {@link ReactivationCampaignJob}
 * with no ambient transaction of its own), {@code REQUIRES_NEW} when called
 * from a raw {@code @TransactionalEventListener(AFTER_COMMIT)} callback
 * that has none ({@link #resolveReactivationsForConfirmedBooking}).
 *
 * <p>Deliberately has no dependency on {@code revenueengine.DecisionEngine}
 * -- {@link ReactivationStrategy} (a {@code RevenueStrategy} the engine
 * collects) already depends on this class, and the engine itself depends on
 * every registered strategy, so this class depending back on the engine
 * (e.g. to drive the discovery sweep from here) would be a circular bean
 * dependency. {@link ReactivationDiscoveryService} owns that instead.
 */
@Service
public class ReactivationCampaignService {

    private final ReactivationCampaignRepository campaignRepository;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final RevenueAttributionService revenueAttributionService;
    private final ApplicationEventPublisher eventPublisher;
    private final ReactivationProperties properties;
    private final Clock clock;

    ReactivationCampaignService(ReactivationCampaignRepository campaignRepository, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository, RevenueAttributionService revenueAttributionService,
            ApplicationEventPublisher eventPublisher, ReactivationProperties properties, Clock clock) {
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
     * {@link ReactivationStrategy#execute}'s one call, made when the
     * Decision Engine picks {@code CUSTOMER_REACTIVATION} for a {@code
     * CUSTOMER_INACTIVE} decision. A no-op if a campaign for this
     * customer's last visit already exists (duplicate protection --
     * belt-and-braces alongside the unique index, and what makes the daily
     * discovery sweep idempotent, see this module's package-info) or the
     * booking/slot no longer resolve. Sends the win-back nudge immediately,
     * unlike {@code rebookengine.RebookCampaignService#startCampaignForCompletedBooking}
     * -- there's no future due date to wait for here, since the whole point
     * is this customer is already overdue by the time this runs.
     */
    @Transactional
    public void startCampaignForInactiveCustomer(UUID lastVisitBookingId, UUID providerId) {
        if (campaignRepository.existsByLastVisitBookingId(lastVisitBookingId)) {
            return;
        }
        Booking lastVisit = bookingRepository.findById(lastVisitBookingId).orElse(null);
        if (lastVisit == null) {
            return;
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(lastVisit.getAvailabilitySlotId()).orElse(null);
        if (slot == null) {
            return;
        }

        Instant now = clock.instant();
        int inactivityDays = (int) Duration.between(slot.getStartsAt(), now).toDays();
        Instant expiresAt = now.plus(properties.followUpWindowDays(), ChronoUnit.DAYS);

        ReactivationCampaign campaign = new ReactivationCampaign(UUID.randomUUID(), providerId,
                lastVisit.getServiceId(), lastVisit.getUserId(), lastVisitBookingId, slot.getStartsAt(),
                inactivityDays, expiresAt, lastVisit.getTotalPrice(), lastVisit.getCurrency(), now);
        campaignRepository.save(campaign);

        String providerName = providerRepository.findById(providerId).map(Provider::getName).orElse(null);
        String serviceName = serviceOfferingRepository.findById(campaign.getServiceId()).map(ServiceOffering::getTitle)
                .orElse(null);
        eventPublisher.publishEvent(new ReactivationOfferReadyEvent(campaign.getId(), campaign.getUserId(),
                campaign.getProviderId(), providerName, serviceName));
    }

    /** {@link ReactivationCampaignJob}'s sweep target for a SENT campaign whose follow-up window has closed unbooked. */
    @Transactional
    public void expireCampaign(UUID campaignId, Instant now) {
        ReactivationCampaign campaign = campaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.isActive()) {
            return;
        }
        campaign.markExpired(now);
        campaignRepository.save(campaign);
        revenueAttributionService.resolve(ActionType.CUSTOMER_REACTIVATION, campaign.getLastVisitBookingId(),
                BigDecimal.ZERO, campaign.getPriceCurrency(), false, now);
    }

    /**
     * {@link ReactivationOutcomeListener}'s one call, fired whenever ANY
     * booking is confirmed -- closes out every still-active campaign for
     * this exact customer+provider pair as a genuine "they came back" win,
     * whether or not they ever saw/clicked the nudge. {@code
     * REQUIRES_NEW}: called from a raw {@code @TransactionalEventListener(AFTER_COMMIT)}
     * callback with no active transaction of its own -- same reasoning as
     * {@code rebookengine.RebookCampaignService#resolveRebookingsForConfirmedBooking}.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void resolveReactivationsForConfirmedBooking(UUID userId, UUID providerId, UUID newBookingId, Instant now) {
        List<ReactivationCampaign> active = campaignRepository.findByUserIdAndProviderIdAndStatus(userId, providerId,
                ReactivationCampaignStatus.SENT);
        if (active.isEmpty()) {
            return;
        }
        Booking newBooking = bookingRepository.findById(newBookingId).orElse(null);
        BigDecimal actualRevenue = newBooking == null ? BigDecimal.ZERO : newBooking.getTotalPrice();
        for (ReactivationCampaign campaign : active) {
            campaign.markBooked(newBookingId, now);
            campaignRepository.save(campaign);
            String currency = newBooking == null ? campaign.getPriceCurrency() : newBooking.getCurrency();
            revenueAttributionService.resolve(ActionType.CUSTOMER_REACTIVATION, campaign.getLastVisitBookingId(),
                    actualRevenue, currency, true, now);
        }
    }

    /**
     * Null if fewer than two completed visits exist -- no pattern to
     * compare against, so only {@link ReactivationProperties}' absolute
     * ceiling applies. Same visit-history-to-average-gap computation as
     * {@code rebookengine.RebookCampaignService} (Booking itself carries no
     * visit timestamp -- see its own doc comment on the bounded-context
     * boundary -- so this bulk-fetches each visit's {@code AvailabilitySlot}
     * for its {@code startsAt}); duplicated rather than shared across
     * modules on purpose, since sibling strategy modules don't depend on
     * each other. Package-private: {@link ReactivationDiscoveryService}'s
     * own helper.
     */
    Long computeAverageIntervalDays(UUID userId, UUID providerId) {
        List<Booking> visitHistory = bookingRepository.findCompletedByUserIdAndProviderIdOrderByVisitDate(userId,
                providerId);
        if (visitHistory.size() < 2) {
            return null;
        }
        Map<UUID, Instant> slotStartTimes = availabilitySlotRepository
                .findAllById(visitHistory.stream().map(Booking::getAvailabilitySlotId).toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, AvailabilitySlot::getStartsAt));
        List<Instant> visitTimes = visitHistory.stream().map(b -> slotStartTimes.get(b.getAvailabilitySlotId()))
                .filter(Objects::nonNull).sorted().toList();
        if (visitTimes.size() < 2) {
            return null;
        }
        long totalDays = 0;
        for (int i = 1; i < visitTimes.size(); i++) {
            totalDays += Duration.between(visitTimes.get(i - 1), visitTimes.get(i)).toDays();
        }
        return totalDays / (visitTimes.size() - 1);
    }
}
