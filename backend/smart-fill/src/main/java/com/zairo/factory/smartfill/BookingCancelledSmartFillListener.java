package com.zairo.factory.smartfill;

import com.zairo.factory.booking.BookingCancelledEvent;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Reacts to a customer cancelling a booking by starting a Smart Fill
 * campaign for the slot it just freed -- same "listen for the event, don't
 * have the publisher depend on you" pattern as {@code
 * notifications.BookingNotificationListener}/{@code
 * payments.BookingCancelledPaymentListener} (see ADR-0002). Deliberately not
 * triggered by {@code booking.BookingPaymentTimeoutJob}'s unpaid-booking
 * sweep, which never publishes this event (nothing was ever paid there to
 * refund, and by the same reasoning nothing has been recovered here either
 * -- see that job's own doc comment); a slot freed by payment timeout is a
 * natural extension point (add a matching listener for a new
 * payment-timeout event) rather than in scope for this first slice.
 */
@Component
class BookingCancelledSmartFillListener {

    private final SmartFillCampaignService campaignService;

    BookingCancelledSmartFillListener(SmartFillCampaignService campaignService) {
        this.campaignService = campaignService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingCancelled(BookingCancelledEvent event) {
        campaignService.startCampaignForCancelledBooking(event.bookingId());
    }
}
