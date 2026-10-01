package com.zairo.factory.payments;

import com.zairo.factory.booking.BookingCompletedEvent;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns a completed booking into a payable {@link BusinessPayout} — the
 * task's own "Business receives money after successful completion of
 * service" requirement. Same {@code AFTER_COMMIT}/{@code REQUIRES_NEW}
 * pattern as {@link BookingCancelledPaymentListener} (see that class's own
 * doc comment for why a post-commit write needs a genuinely new
 * transaction): the booking-completion transaction has already committed
 * by the time this runs, so creating the payout here can never roll back
 * the completion itself.
 */
@Component
class BookingCompletedPayoutListener {

    private final BusinessPayoutService businessPayoutService;

    BookingCompletedPayoutListener(BusinessPayoutService businessPayoutService) {
        this.businessPayoutService = businessPayoutService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    void onBookingCompleted(BookingCompletedEvent event) {
        businessPayoutService.createPayableForCompletedBooking(event.bookingId(), event.providerId());
    }
}
