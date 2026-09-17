package com.zairo.factory.reactivationengine;

import com.zairo.factory.automation.AutomationSettings;
import com.zairo.factory.automation.AutomationSettingsService;
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
 * Lost Customer Recovery as a {@link RevenueStrategy} -- the Decision
 * Engine's strategy for {@link DecisionTrigger#CUSTOMER_INACTIVE}. Unlike
 * every other trigger, this one is only ever raised for candidates {@link
 * ReactivationCandidateDiscoveryJob} already decided are significantly
 * overdue, so {@link #evaluate} only needs to confirm the anchor booking
 * still exists -- the real "is this worth it" filtering already happened
 * before the Decision Engine was even consulted.
 */
@Component
class ReactivationStrategy implements RevenueStrategy {

    private final BookingRepository bookingRepository;
    private final ReactivationProperties properties;
    private final ReactivationCampaignService campaignService;
    private final AutomationSettingsService automationSettingsService;

    ReactivationStrategy(BookingRepository bookingRepository, ReactivationProperties properties,
            ReactivationCampaignService campaignService, AutomationSettingsService automationSettingsService) {
        this.bookingRepository = bookingRepository;
        this.properties = properties;
        this.campaignService = campaignService;
        this.automationSettingsService = automationSettingsService;
    }

    @Override
    public ActionType actionType() {
        return ActionType.CUSTOMER_REACTIVATION;
    }

    @Override
    public Set<DecisionTrigger> triggers() {
        return Set.of(DecisionTrigger.CUSTOMER_INACTIVE);
    }

    @Override
    public StrategyDecision evaluate(DecisionContext context) {
        boolean enabled = automationSettingsService.findByProviderId(context.providerId())
                .map(AutomationSettings::isReactivationEnabled).orElse(true);
        if (!enabled) {
            return StrategyDecision.notApplicable(ActionType.CUSTOMER_REACTIVATION,
                    "Reactivation is disabled for this provider in Automation Center");
        }

        Booking lastVisit = bookingRepository.findById(context.referenceId()).orElse(null);
        if (lastVisit == null) {
            return StrategyDecision.notApplicable(ActionType.CUSTOMER_REACTIVATION,
                    "Customer's last-visit booking no longer exists");
        }

        BigDecimal expectedValue = lastVisit.getTotalPrice();
        String rationale = "Customer has gone significantly quiet with this provider -- a colder lead than a "
                + "routine Rebook nudge, hence the lower probability.";
        return new StrategyDecision(ActionType.CUSTOMER_REACTIVATION, true, expectedValue, lastVisit.getCurrency(),
                properties.baseProbability(), rationale);
    }

    @Override
    public void execute(DecisionContext context, StrategyDecision decision) {
        campaignService.startCampaignForInactiveCustomer(context.referenceId(), context.providerId());
    }
}
