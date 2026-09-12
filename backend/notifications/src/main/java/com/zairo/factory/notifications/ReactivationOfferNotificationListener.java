package com.zairo.factory.notifications;

import com.zairo.factory.reactivationengine.ReactivationOfferReadyEvent;
import com.zairo.factory.users.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns a Lost Customer Recovery win-back nudge into a real notification --
 * same "listen for the event, don't have the publisher depend on you"
 * pattern as {@link RebookOfferNotificationListener} (see ADR-0002). {@code
 * reactivationengine} never calls {@link NotificationService} directly;
 * this is the one place that dependency runs the other way.
 */
@Component
class ReactivationOfferNotificationListener {

    private final UserRepository userRepository;
    private final NotificationService notificationService;

    ReactivationOfferNotificationListener(UserRepository userRepository, NotificationService notificationService) {
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onReactivationOfferReady(ReactivationOfferReadyEvent event) {
        userRepository.findById(event.userId())
                .ifPresent(customer -> notificationService.sendReactivationOfferEmail(customer.getId(),
                        customer.getEmail(), event.providerName(), event.serviceName()));
    }
}
