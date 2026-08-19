package com.zairo.factory.booking;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Placeholder consumer proving the ADR-0002 event-publishing plumbing works
 * end to end. Real consumers (e.g. sending a confirmation notification) plug
 * in the same way once the notifications module has something to send —
 * they don't need booking to depend on them.
 */
@Component
class BookingConfirmedEventListener {

    private static final Logger log = LoggerFactory.getLogger(BookingConfirmedEventListener.class);

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingConfirmed(BookingConfirmedEvent event) {
        log.info("Booking confirmed: bookingId={}, userId={}, providerId={}", event.bookingId(), event.userId(),
                event.providerId());
    }
}
