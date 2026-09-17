package com.zairo.factory.revenueengine;

import com.zairo.factory.booking.BookingCompletedEvent;
import java.time.Instant;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns a completed booking into a {@link DecisionContext} for the {@link
 * DecisionEngine} — same "listen for the event, don't have the publisher
 * depend on you" pattern as {@link BookingCancelledDecisionListener} (ADR-0002).
 * Deliberately thin: it doesn't look up the booking itself — that's each
 * {@link RevenueStrategy}'s own job (today, just {@code rebookengine.RebookStrategy}).
 */
@Component
class BookingCompletedDecisionListener {

    private final DecisionEngine decisionEngine;

    BookingCompletedDecisionListener(DecisionEngine decisionEngine) {
        this.decisionEngine = decisionEngine;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingCompleted(BookingCompletedEvent event) {
        decisionEngine.decideAndExecute(new DecisionContext(DecisionTrigger.BOOKING_COMPLETED, event.providerId(),
                event.bookingId(), Instant.now()));
    }
}
