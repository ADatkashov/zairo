package com.zairo.factory.revenueengine;

/**
 * A moment the Decision Engine is worth consulting. Only triggers with a
 * real publisher and a real listener today are here — {@code
 * booking.BookingNoShowEvent} already exists (event-foundation, see its own
 * doc comment) but has no {@link DecisionContext} listener yet since no
 * strategy consumes it; adding one is: a new constant here, a new {@code
 * @TransactionalEventListener} turning that event into a {@link
 * DecisionContext}, and a {@link RevenueStrategy} that declares it in
 * {@link RevenueStrategy#triggers()}.
 */
public enum DecisionTrigger {
    /** referenceId is the cancelled booking's id. See {@link BookingCancelledDecisionListener}. */
    BOOKING_CANCELLED,
    /** referenceId is the completed booking's id. See {@link BookingCompletedDecisionListener}. */
    BOOKING_COMPLETED,
}
