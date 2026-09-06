package com.zairo.factory.notifications;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.payments.PaymentRefundedEvent;
import com.zairo.factory.users.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Reacts to payments' domain events (see ADR-0002) by emailing the
 * customer — same "listen for the event, don't have the publisher depend
 * on you" pattern as {@link BookingNotificationListener}/{@link
 * SubscriptionNotificationListener}. Only reads (resolving bookingId ->
 * userId -> email), never writes, so no {@code REQUIRES_NEW} is needed.
 */
@Component
class PaymentNotificationListener {

    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    PaymentNotificationListener(BookingRepository bookingRepository, UserRepository userRepository,
            NotificationService notificationService) {
        this.bookingRepository = bookingRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onPaymentRefunded(PaymentRefundedEvent event) {
        bookingRepository.findById(event.bookingId())
                .map(Booking::getUserId)
                .flatMap(userRepository::findById)
                .ifPresent(customer -> notificationService.sendPaymentRefundedEmail(customer.getId(),
                        customer.getEmail(), event.bookingId(), event.amount(), event.currency()));
    }
}
