package com.zairo.factory.payments;

import com.zairo.factory.booking.BookingCancelledEvent;
import java.time.Clock;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reacts to a cancelled booking by durably recording that its payment needs
 * refunding -- see {@link PaymentRefundRequest}'s own doc comment for the
 * full design, and {@code payments.PaymentWebhookProcessor}'s race-F
 * handling for the other place a refund request gets created the same way.
 * Same ADR-0002 in-process-event pattern booking already proved with
 * BookingConfirmedEvent; payments already has a one-directional Gradle
 * dependency on booking (reads Booking/BookingRepository directly
 * elsewhere in this module), so listening for a booking-published event
 * here adds no new coupling.
 *
 * <p>Deliberately a plain {@link EventListener}, not {@code
 * @TransactionalEventListener(AFTER_COMMIT)}: it must run <em>inside</em>
 * the same transaction as {@code BookingService#cancelBooking}'s own write
 * (ADR-0002's synchronous in-process publish means that transaction is
 * still open here), so the refund-request row commits atomically with the
 * cancellation it's for. This class used to do the refund itself --
 * AFTER_COMMIT, in a fresh REQUIRES_NEW transaction, calling {@code
 * PaymentsService#refundPayment} directly and only logging a failure (see
 * git history) -- a crash between the cancellation committing and that
 * listener firing, or any transient Freedom Pay failure, silently lost the
 * refund forever, with no retry. Now this class only ever does one cheap,
 * unlikely-to-fail insert; the actual provider call is made durably and
 * retried by {@code PaymentRefundOutboxProcessor}.
 *
 * <p>Nothing to refund is not an error: a booking cancelled before payment
 * was ever attempted, or one whose payment already failed, simply has no
 * SUCCEEDED payment to act on.
 */
@Component
class BookingCancelledPaymentListener {

    private final PaymentRepository paymentRepository;
    private final PaymentRefundRequestRepository refundRequestRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;
    private final PaymentPartialRefundRepository partialRefundRepository;

    BookingCancelledPaymentListener(PaymentRepository paymentRepository,
            PaymentRefundRequestRepository refundRequestRepository, ApplicationEventPublisher eventPublisher,
            Clock clock, PaymentPartialRefundRepository partialRefundRepository) {
        this.partialRefundRepository = partialRefundRepository;
        this.paymentRepository = paymentRepository;
        this.refundRequestRepository = refundRequestRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    @EventListener
    @Transactional
    void onBookingCancelled(BookingCancelledEvent event) {
        paymentRepository.findByBookingId(event.bookingId())
                .filter(payment -> payment.getStatus() == PaymentStatus.SUCCEEDED)
                .ifPresent(this::createRefundRequest);
    }

    /**
     * {@code payment_id unique} (V63) is the real idempotency guarantee
     * here, not this method -- a duplicate {@link BookingCancelledEvent} for
     * the same booking isn't expected in normal operation ({@code
     * cancelBooking}'s own status guard already makes cancellation a
     * one-time transition), so this deliberately doesn't pre-check-then-
     * insert or catch-and-swallow a constraint violation the way {@code
     * PaymentWebhookEventRecorder} does for genuinely-expected duplicate
     * webhook deliveries: if this ever did fire twice for the same payment,
     * letting the second insert's constraint violation roll back the whole
     * enclosing {@code cancelBooking} transaction is the correct, safe
     * failure mode -- far better than silently creating a second refund
     * request for the same money.
     */
    private void createRefundRequest(Payment payment) {
        var now = clock.instant();
        // What a cheaper replacement already sent back (or still owes back, retried separately) isn't refunded twice.
        var remaining = payment.getAmount().subtract(partialRefundRepository.totalForPayment(payment.getId()));
        if (remaining.signum() <= 0) {
            return;
        }
        PaymentRefundRequest request = refundRequestRepository.save(new PaymentRefundRequest(UUID.randomUUID(),
                payment.getId(), payment.getBookingId(), remaining, payment.getCurrency(),
                payment.getProvider(), payment.getProviderReference(), now));
        payment.markRefundPending(now);
        paymentRepository.save(payment);
        eventPublisher.publishEvent(new PaymentRefundRequestReady(request.getId()));
    }
}
