/**
 * ZAIRO Intelligence Engine (Decision Engine slice): ZAIRO isn't just a
 * booking marketplace -- it should actively find the action that recovers
 * the most revenue for a business right now, compare it against every other
 * action available, take it, and prove what it was worth. This module is
 * the use-case-agnostic core that makes that comparison possible; it owns
 * no scoring/candidate-finding/notification logic of its own.
 *
 * <h2>The seam: {@link com.zairo.factory.revenueengine.RevenueStrategy}</h2>
 * Every concrete play (Smart Fill and Rebook today; lost-customer recovery,
 * gap-fill, targeted promotion, no-show prevention, VIP retention tomorrow)
 * is one {@code @Component implements RevenueStrategy} living in its own
 * module, declaring which {@link com.zairo.factory.revenueengine.DecisionTrigger}s
 * it reacts to. Adding a new strategy is: implement the interface, register
 * it as a Spring bean (auto-discovered — see {@code PlatformApiApplication}'s
 * {@code scanBasePackages}), done. Nothing in this module, {@link
 * com.zairo.factory.revenueengine.DecisionEngine} included, changes.
 *
 * <h2>How a decision happens</h2>
 * <ol>
 *   <li>A domain event fires (today: {@code booking.BookingCancelledEvent}
 *   — see {@link com.zairo.factory.revenueengine.BookingCancelledDecisionListener}
 *   — or {@code booking.BookingCompletedEvent} — see {@link
 *   com.zairo.factory.revenueengine.BookingCompletedDecisionListener}).
 *   <li>It's turned into a {@link com.zairo.factory.revenueengine.DecisionContext}
 *   — trigger + provider + a reference id whose meaning depends on the
 *   trigger (a bookingId for a cancellation or completion).
 *   <li>{@link com.zairo.factory.revenueengine.DecisionEngine} asks every
 *   strategy registered for that trigger to {@code evaluate} the context —
 *   each returns a {@link com.zairo.factory.revenueengine.StrategyDecision}:
 *   is it applicable, expected value, probability. The highest expected
 *   value (value × probability) wins; see the worked example on {@link
 *   com.zairo.factory.revenueengine.DecisionEngine} itself.
 *   <li>The winning strategy's own {@code execute} runs — this is where the
 *   real work (candidate finding, staged notifications, whatever the
 *   strategy actually does) happens; the engine itself never does it.
 *   <li>{@link com.zairo.factory.revenueengine.RevenueAttributionService}
 *   records the decision immediately (status pending) and the strategy
 *   calls back into it once the real outcome is known (booked/not, and for
 *   how much) — this ledger is the source of the "Revenue Recovered by
 *   ZAIRO" metric a future Business Dashboard/AI Advisor reads from.
 * </ol>
 *
 * <h2>Deliberately not built here</h2>
 * Only Smart Fill and Rebook exist so far — {@link
 * com.zairo.factory.revenueengine.ActionType} enumerates the rest
 * (CUSTOMER_REACTIVATION, GAP_FILL, SMART_PROMOTION, NO_SHOW_PREVENTION,
 * VIP_RETENTION) purely so the outcome ledger and any future dashboard
 * already speak the right vocabulary; building the strategies themselves is
 * separate, future work, each its own module depending on this one. No LLM
 * calls anywhere in this module — {@code evaluate()} is deterministic
 * rules/scoring/probability today; a future ML-backed strategy is just
 * another {@code RevenueStrategy} implementation, not a change here.
 */
package com.zairo.factory.revenueengine;
