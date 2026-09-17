package com.zairo.factory.revenueengine;

/**
 * A moment the Decision Engine is worth consulting. Most triggers here are
 * sourced from a single domain event via a {@code
 * @TransactionalEventListener} turning it into a {@link DecisionContext} —
 * adding one of those is: a new constant here, a new listener, and a {@link
 * RevenueStrategy} that declares it in {@link RevenueStrategy#triggers()}.
 * {@link #CUSTOMER_INACTIVE} is the exception: "a customer has gone quiet"
 * isn't a discrete event anything publishes, so it's sourced from a periodic
 * scan instead (see {@code reactivationengine}'s discovery job) that calls
 * {@link DecisionEngine#decideAndExecute} directly for each candidate it
 * finds, rather than through a listener.
 *
 * <p>{@code booking.BookingNoShowEvent} already exists (event-foundation,
 * see its own doc comment) but has no listener yet since no strategy
 * consumes it.
 */
public enum DecisionTrigger {
    /** referenceId is the cancelled booking's id. See {@link BookingCancelledDecisionListener}. */
    BOOKING_CANCELLED,
    /** referenceId is the completed booking's id. See {@link BookingCompletedDecisionListener}. */
    BOOKING_COMPLETED,
    /** referenceId is the customer's most recent completed booking with the provider -- see this enum's own doc comment. */
    CUSTOMER_INACTIVE,
}
