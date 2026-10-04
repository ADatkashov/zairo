package com.zairo.factory.notifications;

import com.zairo.factory.loyalty.ManualGreetingSentEvent;
import com.zairo.factory.users.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Delivers a greeting an owner sent by hand -- same pattern as {@link BirthdayBonusNotificationListener}. */
@Component
class ManualGreetingNotificationListener {

    private final UserRepository userRepository;
    private final NotificationService notificationService;

    ManualGreetingNotificationListener(UserRepository userRepository, NotificationService notificationService) {
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onGreetingSent(ManualGreetingSentEvent event) {
        userRepository.findById(event.userId()).ifPresent(customer -> notificationService
                .sendGreetingNotification(customer.getId(), customer.getEmail(), event.providerName(),
                        event.message(), event.points()));
    }
}
