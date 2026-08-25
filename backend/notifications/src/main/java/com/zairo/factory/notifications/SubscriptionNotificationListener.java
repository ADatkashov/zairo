package com.zairo.factory.notifications;

import com.zairo.factory.subscriptions.SubscriptionPastDueEvent;
import com.zairo.factory.subscriptions.SubscriptionPaymentFailedEvent;
import com.zairo.factory.users.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Reacts to subscriptions' domain events (see ADR-0002) by emailing the
 * owner — same "listen for the event, don't have the publisher depend on
 * you" pattern as {@link BookingNotificationListener}. Only reads (resolving
 * ownerUserId to an email), never writes, so no
 * {@code @Transactional(propagation = REQUIRES_NEW)} is needed — nothing
 * here could be silently lost by joining an already-committed transaction.
 */
@Component
class SubscriptionNotificationListener {

    private final UserRepository userRepository;
    private final NotificationService notificationService;

    SubscriptionNotificationListener(UserRepository userRepository, NotificationService notificationService) {
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onSubscriptionPaymentFailed(SubscriptionPaymentFailedEvent event) {
        userRepository.findById(event.ownerUserId())
                .ifPresent(owner -> notificationService.sendSubscriptionPaymentFailedEmail(owner.getEmail()));
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onSubscriptionPastDue(SubscriptionPastDueEvent event) {
        userRepository.findById(event.ownerUserId())
                .ifPresent(owner -> notificationService.sendSubscriptionDowngradedEmail(owner.getEmail()));
    }
}
