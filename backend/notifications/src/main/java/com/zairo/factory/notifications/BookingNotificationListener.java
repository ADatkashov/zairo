package com.zairo.factory.notifications;

import com.zairo.factory.booking.BookingCancelledEvent;
import com.zairo.factory.booking.BookingConfirmedEvent;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Reacts to booking's domain events (see ADR-0002) by emailing both sides
 * of the booking — the customer, and the salon owner — matching this
 * project's established "listen for the event, don't have the publisher
 * depend on you" pattern (same as payments' BookingCancelledPaymentListener
 * for refunds). Only reads (resolving a userId/providerId to an email
 * address), never writes, so unlike that refund listener this doesn't need
 * {@code @Transactional(propagation = REQUIRES_NEW)} — there's nothing here
 * that could be silently lost by "joining" an already-committed transaction.
 */
@Component
class BookingNotificationListener {

    private final UserRepository userRepository;
    private final ProviderRepository providerRepository;
    private final NotificationService notificationService;

    BookingNotificationListener(UserRepository userRepository, ProviderRepository providerRepository,
            NotificationService notificationService) {
        this.userRepository = userRepository;
        this.providerRepository = providerRepository;
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingConfirmed(BookingConfirmedEvent event) {
        userRepository.findById(event.userId())
                .ifPresent(customer -> notificationService.sendBookingConfirmedEmail(customer.getEmail(),
                        event.bookingId()));
        ownerEmailFor(event.providerId())
                .ifPresent(ownerEmail -> notificationService.sendNewBookingReceivedEmail(ownerEmail,
                        event.bookingId()));
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingCancelled(BookingCancelledEvent event) {
        userRepository.findById(event.userId())
                .ifPresent(customer -> notificationService.sendBookingCancelledEmail(customer.getEmail(),
                        event.bookingId()));
        ownerEmailFor(event.providerId())
                .ifPresent(ownerEmail -> notificationService.sendProviderBookingCancelledEmail(ownerEmail,
                        event.bookingId()));
    }

    private Optional<String> ownerEmailFor(UUID providerId) {
        return providerRepository.findById(providerId)
                .map(Provider::getOwnerUserId)
                .flatMap(userRepository::findById)
                .map(User::getEmail);
    }
}
