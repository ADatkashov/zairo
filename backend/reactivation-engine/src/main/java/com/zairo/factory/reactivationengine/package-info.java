/**
 * Lost Customer Recovery: a customer who used to visit regularly but has
 * gone quiet well past their usual interval (or, absent an established
 * pattern, past a flat long-inactivity floor) is a business's most
 * recoverable lost revenue -- if nobody reaches out, they've likely
 * already found a competitor. This is where Rebook Engine leaves off: a
 * Rebook nudge fires the moment a customer's ordinary cadence elapses and
 * gives up after a short follow-up window; this module is the wider,
 * slower-moving safety net for customers who fell further than that.
 *
 * <h2>How it works</h2>
 * <ol>
 *   <li>{@link com.zairo.factory.reactivationengine.ReactivationCandidateDiscoveryJob}
 *   runs once a day (see ADR-0005) and delegates to {@link
 *   com.zairo.factory.reactivationengine.ReactivationDiscoveryService},
 *   which asks {@code booking.BookingRepository#findLatestCompletedVisitPerUserAndProvider}
 *   for every customer+provider pair's single most recent COMPLETED visit,
 *   platform-wide -- there is no discrete "customer went quiet" event to
 *   listen for (see {@code revenueengine.DecisionTrigger#CUSTOMER_INACTIVE}'s
 *   own doc comment), so this sweep is the trigger itself. (This lives in
 *   its own service, not {@code ReactivationCampaignService}, purely to
 *   avoid a circular bean dependency -- see that service's own doc comment.)
 *   <li>For each pair whose last visit is old enough to even consider (see
 *   {@link com.zairo.factory.reactivationengine.ReactivationProperties}),
 *   the job checks whether they're <em>significantly</em> overdue: either
 *   the gap already exceeds an absolute ceiling regardless of history, or
 *   (once at least two visits establish a pattern) the gap exceeds their
 *   own average interval times a configured multiplier.
 *   <li>Each qualifying pair is handed to {@code
 *   revenueengine.DecisionEngine#decideAndExecute} directly (no listener in
 *   between) with {@code DecisionTrigger.CUSTOMER_INACTIVE}, referencing
 *   that customer's last completed booking. If {@link
 *   com.zairo.factory.reactivationengine.ReactivationStrategy} wins, {@link
 *   com.zairo.factory.reactivationengine.ReactivationCampaignService#startCampaignForInactiveCustomer}
 *   creates a {@link com.zairo.factory.reactivationengine.ReactivationCampaign}
 *   and sends the win-back nudge immediately -- unlike Rebook, there's no
 *   future due date to wait for, since the whole point is they're already
 *   overdue by the time this runs.
 *   <li>{@link com.zairo.factory.reactivationengine.ReactivationCampaignJob}
 *   expires a campaign if the customer hasn't come back within the
 *   (longer than Rebook's) follow-up window; {@link
 *   com.zairo.factory.reactivationengine.ReactivationOutcomeListener}
 *   closes it out as recovered the moment {@code booking.BookingConfirmedEvent}
 *   shows this exact customer booking with this exact provider again.
 * </ol>
 *
 * <p>Anchoring each campaign to the customer's actual last-visit booking id
 * (rather than, say, today's date) makes the daily sweep naturally
 * idempotent: {@code existsByLastVisitBookingId} means a still-inactive
 * pair the sweep keeps re-finding every day only ever gets one campaign,
 * until they book again and get a new "last visit" to anchor on.
 *
 * <h2>Deliberately not built here</h2>
 * No discount, no Smart Promotion integration -- this module only decides
 * <em>whether and when</em> to reach out, never what incentive (if any) to
 * offer; that's Smart Promotion Engine's job, a separate future strategy.
 * No candidate scoring or staged rollout (one customer per campaign, same
 * reasoning as {@code rebookengine}'s own doc comment).
 */
package com.zairo.factory.reactivationengine;
