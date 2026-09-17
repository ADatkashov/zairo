package com.zairo.factory.notifications;

import com.zairo.factory.smartfill.SmartFillOfferReadyEvent;
import com.zairo.factory.users.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns a Smart Fill offer into a real notification -- same "listen for the
 * event, don't have the publisher depend on you" pattern as {@link
 * BookingNotificationListener} (see ADR-0002). {@code smartfill} never
 * calls {@link NotificationService} directly; this is the one place that
 * dependency runs the other way.
 */
@Component
class SmartFillOfferNotificationListener {

    private final UserRepository userRepository;
    private final NotificationService notificationService;

    SmartFillOfferNotificationListener(UserRepository userRepository, NotificationService notificationService) {
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onSmartFillOfferReady(SmartFillOfferReadyEvent event) {
        userRepository.findById(event.userId())
                .ifPresent(customer -> notificationService.sendSmartFillOfferEmail(customer.getId(),
                        customer.getEmail(), event.providerName(), event.serviceName(), event.employeeName(),
                        event.slotStartsAt()));
    }
}
