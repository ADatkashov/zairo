package com.zairo.factory.smartfill;

import com.zairo.factory.booking.AvailabilitySlotBookedEvent;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Closes out any campaign still active for a slot the instant it's claimed
 * by anyone -- a Smart Fill candidate accepting their offer, or an unrelated
 * customer who found the slot another way. See ADR-0002 for the event
 * pattern and {@link SmartFillCampaignService#completeCampaignsForBookedSlot}
 * for what "closes out" actually does.
 */
@Component
class SlotBookedSmartFillListener {

    private final SmartFillCampaignService campaignService;

    SlotBookedSmartFillListener(SmartFillCampaignService campaignService) {
        this.campaignService = campaignService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onAvailabilitySlotBooked(AvailabilitySlotBookedEvent event) {
        campaignService.completeCampaignsForBookedSlot(event.availabilitySlotId(), event.bookingId());
    }
}
