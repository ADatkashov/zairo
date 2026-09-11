package com.zairo.factory.revenueengine;

import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Picks the single best {@link RevenueStrategy} for a {@link DecisionContext}
 * and runs it. Not tied to any one use case — every strategy registered for
 * the context's {@link DecisionTrigger} gets an equal chance to {@link
 * RevenueStrategy#evaluate}, and the one with the highest {@link
 * StrategyDecision#priorityScore()} (expected value × probability) wins.
 *
 * <p>Worked example (the one this module was designed around): a 15:00 slot
 * just freed up. If a Rebooking strategy and a Smart Promotion strategy
 * both existed alongside Smart Fill, a single {@code BOOKING_CANCELLED}
 * decision might see:
 * <pre>
 *   SMART_FILL:            expected ₸15,000 × 82% = ₸12,300
 *   CUSTOMER_REACTIVATION: expected ₸15,000 × 35% = ₸5,250
 *   SMART_PROMOTION:       expected ₸12,000 × 60% = ₸7,200   (discounted price)
 * </pre>
 * Smart Fill wins — highest expected value, no discount needed. Today only
 * Smart Fill is registered, so it always wins by default when applicable;
 * the comparison becomes real the moment a second strategy is added, with
 * no change to this class.
 *
 * <p>{@code REQUIRES_NEW}: every caller is a {@code
 * @TransactionalEventListener(phase = AFTER_COMMIT)} (see {@link
 * BookingCancelledDecisionListener}) — same reasoning as {@code
 * notifications.NotificationService}'s identical doc comment.
 */
@Service
public class DecisionEngine {

    private final List<RevenueStrategy> strategies;
    private final RevenueAttributionService attributionService;

    public DecisionEngine(List<RevenueStrategy> strategies, RevenueAttributionService attributionService) {
        this.strategies = strategies;
        this.attributionService = attributionService;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void decideAndExecute(DecisionContext context) {
        RevenueStrategy chosenStrategy = null;
        StrategyDecision chosenDecision = null;

        for (RevenueStrategy strategy : strategies) {
            if (!strategy.triggers().contains(context.trigger())) {
                continue;
            }
            StrategyDecision decision = strategy.evaluate(context);
            if (!decision.applicable()) {
                continue;
            }
            if (chosenDecision == null || decision.priorityScore().compareTo(chosenDecision.priorityScore()) > 0) {
                chosenStrategy = strategy;
                chosenDecision = decision;
            }
        }

        if (chosenStrategy == null) {
            attributionService.recordNoAction(context);
            return;
        }

        attributionService.recordDecision(context, chosenDecision);
        chosenStrategy.execute(context, chosenDecision);
    }
}
