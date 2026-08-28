package com.zairo.factory.payments;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.paymentprovider.PaymentProvider;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PaymentsService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;
    private final PaymentProvider paymentProvider;

    public PaymentsService(PaymentRepository paymentRepository, BookingRepository bookingRepository,
            PaymentProvider paymentProvider) {
        this.paymentRepository = paymentRepository;
        this.bookingRepository = bookingRepository;
        this.paymentProvider = paymentProvider;
    }

    /**
     * One payment per booking for now — full totalPrice, not a partial
     * deposit percentage. Splitting "deposit vs full payment" is a
     * business policy decision deferred until there's a real product
     * requirement for it (see SESSION_NOTES.md).
     *
     * <p>A booking whose only existing payment is FAILED retries against
     * that <em>same</em> row rather than inserting a new one — both
     * because {@code booking_id} is unique on the payment table (a second
     * insert would 500) and, more importantly, because reusing the row
     * keeps {@code paymentId} stable across retries, which is exactly the
     * idempotency key {@link PaymentProvider} promises a real provider
     * (see its doc comment) — minting a fresh id per retry would silently
     * defeat that guarantee.
     */
    @Transactional
    public Payment createPayment(UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        Payment payment = paymentRepository.findByBookingId(bookingId).map(existing -> {
            if (existing.getStatus() != PaymentStatus.FAILED) {
                throw new PaymentConflictException("Booking already has a payment: " + bookingId);
            }
            return existing;
        }).orElseGet(() -> {
            // The booking's own currency, not an independently configured
            // default — see Money migration notes (SESSION_NOTES.md): two
            // separately-configured "USD" defaults that happened to agree
            // were a real latent bug (they could silently diverge), not a
            // feature.
            return paymentRepository.save(new Payment(UUID.randomUUID(), bookingId, booking.getTotalPrice(),
                    booking.getCurrency(), Instant.now()));
        });

        charge(payment);
        return paymentRepository.save(payment);
    }

    /**
     * A declined charge (succeeded=false) and a provider-side exception
     * (network error, timeout) both leave the payment FAILED rather than
     * letting the exception propagate and roll back this transaction —
     * losing the just-persisted payment row would mint a new idempotency
     * key on the next retry (see createPayment's doc comment), silently
     * defeating the whole point of keying charges by paymentId.
     */
    private void charge(Payment payment) {
        PaymentProvider.ChargeResult result;
        try {
            result = paymentProvider.charge(payment.getId(), payment.getAmount(), payment.getCurrency());
        } catch (RuntimeException e) {
            payment.markFailed("Payment provider error: " + e.getMessage(), Instant.now());
            return;
        }
        if (result.succeeded()) {
            payment.markSucceeded(result.providerReference(), Instant.now());
        } else {
            payment.markFailed(result.failureReason(), Instant.now());
        }
    }

    // noRollbackFor: the BAD_GATEWAY branch below deliberately persists the
    // refund-failure fact on the payment row before throwing — a bare
    // @Transactional would roll that write back along with the exception
    // (ResponseStatusException is unchecked), silently undoing the whole
    // point of recording it.
    @Transactional(noRollbackFor = ResponseStatusException.class)
    public Payment refundPayment(UUID paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Payment not found: "
                        + paymentId));

        if (payment.getStatus() != PaymentStatus.SUCCEEDED) {
            throw new PaymentConflictException("Only a succeeded payment can be refunded: " + paymentId
                    + " (status=" + payment.getStatus() + ")");
        }

        PaymentProvider.RefundResult result = paymentProvider.refund(payment.getId(), payment.getProviderReference(),
                payment.getAmount());
        if (!result.succeeded()) {
            // Recorded on the row before throwing — a failed refund used to
            // be visible only in whatever caller's log line happened to
            // catch this exception (see BookingCancelledPaymentListener).
            // Now it's a durable, queryable fact on the payment itself:
            // still SUCCEEDED with a non-null refundFailureReason means
            // "money owed back, not yet returned."
            payment.markRefundFailed(result.failureReason(), Instant.now());
            paymentRepository.save(payment);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Refund failed: " + result.failureReason());
        }
        payment.markRefunded(Instant.now());
        return paymentRepository.save(payment);
    }
}
