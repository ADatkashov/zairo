package com.zairo.factory.reactivationengine;

import com.zairo.factory.booking.BookingConfirmedEvent;
import java.time.Clock;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Closes out any active {@link ReactivationCampaign} the moment its
 * customer books again with the same provider -- listens for every
 * confirmed booking (not just ones that came from a nudge) since an organic
 * rebooking a customer made on their own initiative is just as real a win;
 * see {@link ReactivationCampaignService#resolveReactivationsForConfirmedBooking}'s
 * own doc comment. Same "listen for the event, don't have the publisher
 * depend on you" pattern as every other domain-event listener in this
 * codebase (ADR-0002).
 */
@Component
class ReactivationOutcomeListener {

    private final ReactivationCampaignService campaignService;
    private final Clock clock;

    ReactivationOutcomeListener(ReactivationCampaignService campaignService, Clock clock) {
        this.campaignService = campaignService;
        this.clock = clock;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingConfirmed(BookingConfirmedEvent event) {
        campaignService.resolveReactivationsForConfirmedBooking(event.userId(), event.providerId(), event.bookingId(),
                clock.instant());
    }
}
