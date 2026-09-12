/**
 * Rebook Engine: a customer who visits a business on a predictable cadence
 * (haircut every 5 weeks, oil change every 3 months) is a business's most
 * reliable revenue -- if ZAIRO already knows that cadence, it can nudge them
 * back before they drift to a competitor, instead of the business hoping
 * they remember on their own.
 *
 * <h2>How it works</h2>
 * <ol>
 *   <li>{@code booking.BookingCompletedEvent} fires when a provider owner
 *   marks a booking COMPLETED -- turned into a {@code
 *   revenueengine.DecisionContext} by {@code
 *   revenueengine.BookingCompletedDecisionListener}.
 *   <li>{@link com.zairo.factory.rebookengine.RebookStrategy#evaluate} is a
 *   cheap check: does this customer have enough COMPLETED visit history with
 *   this provider to establish a usual interval at all? The real interval
 *   computation happens once, inside {@code execute()}, via {@link
 *   com.zairo.factory.rebookengine.RebookCampaignService}.
 *   <li>If Rebook wins the Decision Engine's comparison, {@link
 *   com.zairo.factory.rebookengine.RebookCampaignService#startCampaignForCompletedBooking}
 *   averages the gaps between this customer's past visits (clamped to a
 *   sane range -- see {@link com.zairo.factory.rebookengine.RebookProperties})
 *   and creates a {@link com.zairo.factory.rebookengine.RebookCampaign} due
 *   on the date that pattern predicts their next visit.
 *   <li>{@link com.zairo.factory.rebookengine.RebookCampaignJob} (see
 *   ADR-0005) sends the nudge once a campaign's {@code dueAt} arrives, and
 *   expires it if the customer hasn't come back by {@code expiresAt}.
 *   <li>{@link com.zairo.factory.rebookengine.RebookOutcomeListener} closes
 *   a campaign out as a win the moment {@code booking.BookingConfirmedEvent}
 *   shows this exact customer booking again with this exact provider --
 *   whether or not they ever saw the nudge (an organic rebooking still
 *   counts; see that class's own doc comment).
 * </ol>
 *
 * <h2>Deliberately not built here</h2>
 * No candidate scoring, no staged rollout, no customer-facing "accept this
 * offer" endpoint -- unlike Smart Fill, there's exactly one customer per
 * campaign and no competing candidates, so the nudge just points them back
 * at the ordinary booking flow. A dedicated owner-facing performance panel
 * (mirroring {@code smartfill.SmartFillAnalyticsService}) is a natural
 * follow-up once this has real usage, not built here -- the generic
 * "Revenue Recovered by ZAIRO" summary already breaks out {@code
 * revenueengine.ActionType#REBOOK} today.
 */
package com.zairo.factory.rebookengine;
