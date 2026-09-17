package com.zairo.factory.revenueengine;

import java.util.Set;

/**
 * One revenue-recovery play the {@link DecisionEngine} can compare against
 * every other one — see this package's own doc comment for the full
 * lifecycle. A new strategy is a new {@code @Component} implementing this,
 * declared in its own module depending on this one (never the reverse —
 * see revenue-engine's build.gradle.kts).
 */
public interface RevenueStrategy {

    ActionType actionType();

    /** Which {@link DecisionTrigger}s this strategy wants a chance to evaluate. */
    Set<DecisionTrigger> triggers();

    /**
     * Cheap and side-effect-free: real work (candidate finding, etc.) belongs
     * in {@link #execute}, not here — {@link DecisionEngine} calls this for
     * every registered strategy on every matching trigger, so it needs to
     * stay fast even as more strategies are added.
     */
    StrategyDecision evaluate(DecisionContext context);

    /**
     * Called at most once per {@link DecisionContext}, only for the winning
     * {@link StrategyDecision} — do the actual work here (this is where
     * {@code smartfill.SmartFillStrategy} hands off to {@code
     * SmartFillCampaignService}).
     */
    void execute(DecisionContext context, StrategyDecision decision);
}
