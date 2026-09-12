package com.zairo.factory.rebookengine;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.revenueengine.ActionType;
import com.zairo.factory.revenueengine.DecisionContext;
import com.zairo.factory.revenueengine.DecisionTrigger;
import com.zairo.factory.revenueengine.RevenueStrategy;
import com.zairo.factory.revenueengine.StrategyDecision;
import java.math.BigDecimal;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * Rebook as a {@link RevenueStrategy} -- the Decision Engine's strategy for
 * {@link DecisionTrigger#BOOKING_COMPLETED}. {@link #evaluate} stays
 * deliberately cheap (a visit-history existence check, not the real interval
 * computation) since {@link com.zairo.factory.revenueengine.DecisionEngine}
 * calls it for every applicable candidate strategy on every completion; the
 * real work -- averaging visit gaps and scheduling the nudge -- happens once,
 * inside {@link #execute}, via {@link RebookCampaignService}.
 */
@Component
class RebookStrategy implements RevenueStrategy {

    private final BookingRepository bookingRepository;
    private final RebookProperties properties;
    private final RebookCampaignService campaignService;

    RebookStrategy(BookingRepository bookingRepository, RebookProperties properties,
            RebookCampaignService campaignService) {
        this.bookingRepository = bookingRepository;
        this.properties = properties;
        this.campaignService = campaignService;
    }

    @Override
    public ActionType actionType() {
        return ActionType.REBOOK;
    }

    @Override
    public Set<DecisionTrigger> triggers() {
        return Set.of(DecisionTrigger.BOOKING_COMPLETED);
    }

    @Override
    public StrategyDecision evaluate(DecisionContext context) {
        Booking completedBooking = bookingRepository.findById(context.referenceId()).orElse(null);
        if (completedBooking == null) {
            return StrategyDecision.notApplicable(ActionType.REBOOK, "Completed booking no longer exists");
        }

        // A cheap existence check, not the real average-interval computation
        // (that's RebookCampaignService's job, run once inside execute()) --
        // enough visit history to even bother establishing a cadence is what
        // actually signals this is worth comparing against other strategies.
        int visitCount = bookingRepository
                .findCompletedByUserIdAndProviderIdOrderByVisitDate(completedBooking.getUserId(),
                        context.providerId())
                .size();
        if (visitCount < properties.minVisitsToEstablishInterval()) {
            return StrategyDecision.notApplicable(ActionType.REBOOK,
                    "Not enough visit history with this provider to establish a rebooking interval");
        }

        BigDecimal expectedValue = completedBooking.getTotalPrice();
        String rationale = "Customer has " + visitCount
                + " completed visits with this provider -- likely to return on a predictable cadence.";
        return new StrategyDecision(ActionType.REBOOK, true, expectedValue, completedBooking.getCurrency(),
                properties.baseProbability(), rationale);
    }

    @Override
    public void execute(DecisionContext context, StrategyDecision decision) {
        campaignService.startCampaignForCompletedBooking(context.referenceId());
    }
}
