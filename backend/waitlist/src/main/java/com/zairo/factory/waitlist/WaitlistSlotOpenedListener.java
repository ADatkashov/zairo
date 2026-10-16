package com.zairo.factory.waitlist;

import com.zairo.factory.booking.AvailabilitySlotOpenedEvent;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
class WaitlistSlotOpenedListener {

    private final WaitlistService waitlistService;

    WaitlistSlotOpenedListener(WaitlistService waitlistService) {
        this.waitlistService = waitlistService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onSlotOpened(AvailabilitySlotOpenedEvent event) {
        waitlistService.slotOpened(event);
    }
}
