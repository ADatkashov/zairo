package com.zairo.factory.notifications;

import com.zairo.factory.rebookengine.RebookOfferReadyEvent;
import com.zairo.factory.users.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns a Rebook nudge into a real notification -- same "listen for the
 * event, don't have the publisher depend on you" pattern as {@link
 * SmartFillOfferNotificationListener} (see ADR-0002). {@code rebookengine}
 * never calls {@link NotificationService} directly; this is the one place
 * that dependency runs the other way.
 */
@Component
class RebookOfferNotificationListener {

    private final UserRepository userRepository;
    private final NotificationService notificationService;

    RebookOfferNotificationListener(UserRepository userRepository, NotificationService notificationService) {
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onRebookOfferReady(RebookOfferReadyEvent event) {
        userRepository.findById(event.userId())
                .ifPresent(customer -> notificationService.sendRebookOfferEmail(customer.getId(), customer.getEmail(),
                        event.providerName(), event.serviceName()));
    }
}
