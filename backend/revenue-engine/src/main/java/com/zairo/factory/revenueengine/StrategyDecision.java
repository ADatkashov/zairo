package com.zairo.factory.revenueengine;

import java.math.BigDecimal;

/**
 * One {@link RevenueStrategy}'s answer to "should I run, and how much is it
 * worth" for a given {@link DecisionContext}. {@link #priorityScore()} —
 * expected value × probability — is what {@link DecisionEngine} ranks
 * competing strategies by; see its own doc comment for a worked example
 * (Smart Fill 82% vs. Reactivation 35% vs. a discounted Promotion at 60%).
 *
 * @param expectedValue the revenue this action could realistically recover if it works — never a guessed flat
 *                       number; every strategy derives it from real prices (see {@code smartfill.SmartFillStrategy}).
 * @param probability    0.0-1.0, this strategy's own confidence it converts.
 * @param rationale      short human-readable reason, surfaced by a future Business AI Advisor/dashboard —
 *                       never itself LLM-generated (see this package's own doc comment).
 */
public record StrategyDecision(ActionType actionType, boolean applicable, BigDecimal expectedValue, String currency,
        double probability, String rationale) {

    public static StrategyDecision notApplicable(ActionType actionType, String rationale) {
        return new StrategyDecision(actionType, false, BigDecimal.ZERO, null, 0.0, rationale);
    }

    /** What {@link DecisionEngine} maximizes over — never negative, since expectedValue/probability never are. */
    public BigDecimal priorityScore() {
        return expectedValue.multiply(BigDecimal.valueOf(probability));
    }
}
