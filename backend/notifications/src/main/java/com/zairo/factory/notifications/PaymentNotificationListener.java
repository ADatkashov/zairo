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
 * SubscriptionNotificationListener}. This listener itself only reads
 * (resolving bookingId -> userId -> email); the in-app notification write
 * {@link NotificationService#sendPaymentRefundedEmail} makes is its own
 * {@code REQUIRES_NEW} transaction (see that method's doc comment), so
 * nothing extra is needed here.
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
