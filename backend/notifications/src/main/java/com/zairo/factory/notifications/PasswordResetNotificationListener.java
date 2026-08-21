package com.zairo.factory.notifications;

import com.zairo.factory.auth.PasswordResetRequestedEvent;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Delivers the reset code auth generated — see PasswordResetRequestedEvent's
 * doc comment for why this is an event listener rather than auth calling
 * NotificationService directly.
 */
@Component
class PasswordResetNotificationListener {

    private final NotificationService notificationService;

    PasswordResetNotificationListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onPasswordResetRequested(PasswordResetRequestedEvent event) {
        notificationService.sendPasswordResetEmail(event.email(), event.resetToken());
    }
}
