package com.zairo.factory.payments;

import com.zairo.factory.booking.BookingCancelledEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Reacts to a cancelled booking by refunding its payment, if one succeeded —
 * same ADR-0002 in-process-event pattern booking already proved with
 * BookingConfirmedEvent (see BookingConfirmedEventListener). payments
 * already has a one-directional Gradle dependency on booking (reads
 * Booking/BookingRepository directly), so listening for a booking-published
 * event here adds no new coupling.
 *
 * <p>Nothing to refund is not an error: a booking cancelled before payment
 * was ever attempted, or one whose payment already failed, simply has no
 * SUCCEEDED payment to act on.
 */
@Component
class BookingCancelledPaymentListener {

    private static final Logger log = LoggerFactory.getLogger(BookingCancelledPaymentListener.class);

    private final PaymentRepository paymentRepository;
    private final PaymentsService paymentsService;

    BookingCancelledPaymentListener(PaymentRepository paymentRepository, PaymentsService paymentsService) {
        this.paymentRepository = paymentRepository;
        this.paymentsService = paymentsService;
    }

    /**
     * {@code REQUIRES_NEW}, not the default {@code REQUIRED}: this method
     * runs inside the AFTER_COMMIT synchronization callback of the booking-
     * cancellation transaction, which by this point has already committed
     * but may still be thread-bound during Spring's own cleanup. Joining
     * that transaction (the default) let {@link PaymentsService#refundPayment}
     * appear to succeed — the returned entity showed REFUNDED — while the
     * write was silently never durably committed. A genuinely new,
     * independent transaction is required for a write inside a post-commit
     * hook to actually persist.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    void onBookingCancelled(BookingCancelledEvent event) {
        paymentRepository.findByBookingId(event.bookingId())
                .filter(payment -> payment.getStatus() == PaymentStatus.SUCCEEDED)
                .ifPresent(payment -> {
                    try {
                        paymentsService.refundPayment(payment.getId());
                    } catch (RuntimeException e) {
                        // Booking cancellation already committed by the time this
                        // runs — a refund failure here can't roll that back, and
                        // has no HTTP caller left to report to. Logged for a human
                        // to reconcile manually until this project has a real
                        // reconciliation/retry mechanism, which isn't warranted
                        // before there's a real (non-mock) payment provider.
                        log.error("Refund failed for cancelled booking {} (payment {}): {}", event.bookingId(),
                                payment.getId(), e.getMessage(), e);
                    }
                });
    }
}
