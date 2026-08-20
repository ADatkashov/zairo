package com.zairo.factory.payments;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PaymentsService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;
    private final PaymentProvider paymentProvider;
    private final String defaultCurrency;

    public PaymentsService(PaymentRepository paymentRepository, BookingRepository bookingRepository,
            PaymentProvider paymentProvider, @Value("${app.payments.currency:USD}") String defaultCurrency) {
        this.paymentRepository = paymentRepository;
        this.bookingRepository = bookingRepository;
        this.paymentProvider = paymentProvider;
        this.defaultCurrency = defaultCurrency;
    }

    /**
     * One payment per booking for now — full totalPrice, not a partial
     * deposit percentage. Splitting "deposit vs full payment" is a
     * business policy decision deferred until there's a real product
     * requirement for it (see SESSION_NOTES.md).
     */
    @Transactional
    public Payment createPayment(UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        paymentRepository.findByBookingId(bookingId).ifPresent(existing -> {
            if (existing.getStatus() == PaymentStatus.SUCCEEDED || existing.getStatus() == PaymentStatus.PENDING) {
                throw new PaymentConflictException("Booking already has a payment: " + bookingId);
            }
        });

        Instant now = Instant.now();
        Payment payment = new Payment(UUID.randomUUID(), bookingId, booking.getTotalPrice(), defaultCurrency, now);
        payment = paymentRepository.save(payment);

        PaymentProvider.ChargeResult result = paymentProvider.charge(payment.getId(), payment.getAmount(),
                payment.getCurrency());
        if (result.succeeded()) {
            payment.markSucceeded(result.providerReference(), Instant.now());
        } else {
            payment.markFailed(result.failureReason(), Instant.now());
        }
        return paymentRepository.save(payment);
    }

    @Transactional
    public Payment refundPayment(UUID paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Payment not found: "
                        + paymentId));

        if (payment.getStatus() != PaymentStatus.SUCCEEDED) {
            throw new PaymentConflictException("Only a succeeded payment can be refunded: " + paymentId
                    + " (status=" + payment.getStatus() + ")");
        }

        PaymentProvider.RefundResult result = paymentProvider.refund(payment.getProviderReference(),
                payment.getAmount());
        if (!result.succeeded()) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Refund failed: " + result.failureReason());
        }
        payment.markRefunded(Instant.now());
        return paymentRepository.save(payment);
    }
}
