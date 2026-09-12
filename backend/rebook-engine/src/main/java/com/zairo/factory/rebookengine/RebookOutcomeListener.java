package com.zairo.factory.rebookengine;

import com.zairo.factory.booking.BookingConfirmedEvent;
import java.time.Clock;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Closes out any active {@link RebookCampaign} the moment its customer books
 * again with the same provider -- listens for every confirmed booking
 * (not just ones that came from a nudge) since an organic rebooking a
 * customer made on their own initiative is just as real a win; see {@link
 * RebookCampaignService#resolveRebookingsForConfirmedBooking}'s own doc
 * comment. Same "listen for the event, don't have the publisher depend on
 * you" pattern as every other domain-event listener in this codebase
 * (ADR-0002).
 */
@Component
class RebookOutcomeListener {

    private final RebookCampaignService campaignService;
    private final Clock clock;

    RebookOutcomeListener(RebookCampaignService campaignService, Clock clock) {
        this.campaignService = campaignService;
        this.clock = clock;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingConfirmed(BookingConfirmedEvent event) {
        campaignService.resolveRebookingsForConfirmedBooking(event.userId(), event.providerId(), event.bookingId(),
                clock.instant());
    }
}
