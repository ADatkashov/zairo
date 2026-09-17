package com.zairo.factory.revenueengine;

import com.zairo.factory.booking.BookingCancelledEvent;
import java.time.Instant;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns a cancelled booking into a {@link DecisionContext} for the {@link
 * DecisionEngine} — same "listen for the event, don't have the publisher
 * depend on you" pattern as every other domain-event listener in this
 * codebase (ADR-0002). Deliberately thin: it doesn't look up the booking or
 * its slot itself — that's each {@link RevenueStrategy}'s own job, since
 * different strategies may need different data for the same trigger.
 */
@Component
class BookingCancelledDecisionListener {

    private final DecisionEngine decisionEngine;

    BookingCancelledDecisionListener(DecisionEngine decisionEngine) {
        this.decisionEngine = decisionEngine;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingCancelled(BookingCancelledEvent event) {
        decisionEngine.decideAndExecute(new DecisionContext(DecisionTrigger.BOOKING_CANCELLED, event.providerId(),
                event.bookingId(), Instant.now()));
    }
}
