package com.zairo.factory.notifications;

import com.zairo.factory.loyalty.BirthdayBonusAwardedEvent;
import com.zairo.factory.users.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns a birthday bonus into a greeting -- same "listen for the event, don't have the publisher depend on you"
 * pattern as {@link ReactivationOfferNotificationListener} (see ADR-0002).
 */
@Component
class BirthdayBonusNotificationListener {

    private final UserRepository userRepository;
    private final NotificationService notificationService;

    BirthdayBonusNotificationListener(UserRepository userRepository, NotificationService notificationService) {
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBirthdayBonusAwarded(BirthdayBonusAwardedEvent event) {
        userRepository.findById(event.userId()).ifPresent(customer -> notificationService
                .sendBirthdayBonusNotification(customer.getId(), customer.getEmail(), event.providerName(),
                        event.points()));
    }
}
