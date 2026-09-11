package com.zairo.factory.smartfill;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.favorites.FavoriteRepository;
import com.zairo.factory.revenueengine.ActionType;
import com.zairo.factory.revenueengine.DecisionContext;
import com.zairo.factory.revenueengine.DecisionTrigger;
import com.zairo.factory.revenueengine.RevenueStrategy;
import com.zairo.factory.revenueengine.StrategyDecision;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.math.BigDecimal;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * Smart Fill as a {@link RevenueStrategy} -- the Decision Engine's first
 * (and today, only) registered strategy for {@link DecisionTrigger#BOOKING_CANCELLED}.
 * {@link #evaluate} stays deliberately cheap (a existence check, not full
 * candidate scoring) since {@link com.zairo.factory.revenueengine.DecisionEngine}
 * calls it for every applicable candidate strategy on every cancellation;
 * the real work -- finding, scoring, and staging candidates -- happens once,
 * inside {@link #execute}, via the existing {@link SmartFillCampaignService}.
 */
@Component
class SmartFillStrategy implements RevenueStrategy {

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final FavoriteRepository favoriteRepository;
    private final SmartFillCampaignService campaignService;

    SmartFillStrategy(BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            ServiceOfferingRepository serviceOfferingRepository, FavoriteRepository favoriteRepository,
            SmartFillCampaignService campaignService) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.favoriteRepository = favoriteRepository;
        this.campaignService = campaignService;
    }

    @Override
    public ActionType actionType() {
        return ActionType.SMART_FILL;
    }

    @Override
    public Set<DecisionTrigger> triggers() {
        return Set.of(DecisionTrigger.BOOKING_CANCELLED);
    }

    @Override
    public StrategyDecision evaluate(DecisionContext context) {
        Booking cancelledBooking = bookingRepository.findById(context.referenceId()).orElse(null);
        if (cancelledBooking == null) {
            return StrategyDecision.notApplicable(ActionType.SMART_FILL, "Cancelled booking no longer exists");
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(cancelledBooking.getAvailabilitySlotId())
                .orElse(null);
        if (slot == null || slot.getStatus() != AvailabilityStatus.OPEN) {
            return StrategyDecision.notApplicable(ActionType.SMART_FILL, "Slot is no longer open -- already re-booked");
        }
        ServiceOffering service = serviceOfferingRepository.findById(cancelledBooking.getServiceId()).orElse(null);
        if (service == null) {
            return StrategyDecision.notApplicable(ActionType.SMART_FILL, "Service no longer exists");
        }

        // A cheap existence check, not the real scored candidate pool (that's
        // CandidateFinder's job, run once inside execute()) -- "more than
        // just the booking that was just cancelled" is what actually signals
        // a prior relationship worth notifying.
        boolean hasRelationship = bookingRepository.findByProviderId(slot.getProviderId()).size() > 1
                || !favoriteRepository.findByProviderId(slot.getProviderId()).isEmpty();
        double probability = hasRelationship ? 0.7 : 0.1;
        BigDecimal expectedValue = service.getPrice().multiply(BigDecimal.valueOf(probability));
        String rationale = hasRelationship
                ? "Provider has previous customers/followers to notify"
                : "No prior customer relationship with this provider yet -- low confidence";
        return new StrategyDecision(ActionType.SMART_FILL, true, expectedValue, service.getCurrency(), probability,
                rationale);
    }

    @Override
    public void execute(DecisionContext context, StrategyDecision decision) {
        campaignService.startCampaignForCancelledBooking(context.referenceId());
    }
}
