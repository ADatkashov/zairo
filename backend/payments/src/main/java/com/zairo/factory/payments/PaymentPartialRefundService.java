package com.zairo.factory.payments;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingPriceReducedEvent;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.paymentprovider.PaymentProvider;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.util.Currency;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Returns the part of a payment that exceeds a booking's new, lower price (the booking moved to a cheaper worker; the
 * customer never pays more than agreed, and pays the lower price when the replacement is cheaper). The payment stays
 * SUCCEEDED; a {@link PaymentPartialRefund} row records what went back, the booking's paid amount drops accordingly,
 * and the business payout later excludes the business's share of it.
 *
 * <p>Not done while the business payout is already PROCESSING/PAID — the same guard as a full refund: that money has
 * left ZAIRO's control, so it needs manual reconciliation. A failed provider call leaves the row FAILED and is retried
 * by {@link #retryDue()}.
 */
@Component
public class PaymentPartialRefundService {

    private static final Logger log = LoggerFactory.getLogger(PaymentPartialRefundService.class);

    private final PaymentRepository paymentRepository;
    private final PaymentPartialRefundRepository refundRepository;
    private final PaymentAllocationRepository allocationRepository;
    private final BusinessPayoutRepository payoutRepository;
    private final BookingRepository bookingRepository;
    private final PaymentProvider paymentProvider;
    private final Clock clock;

    PaymentPartialRefundService(PaymentRepository paymentRepository, PaymentPartialRefundRepository refundRepository,
            PaymentAllocationRepository allocationRepository, BusinessPayoutRepository payoutRepository,
            BookingRepository bookingRepository, PaymentProvider paymentProvider, Clock clock) {
        this.paymentRepository = paymentRepository;
        this.refundRepository = refundRepository;
        this.allocationRepository = allocationRepository;
        this.payoutRepository = payoutRepository;
        this.bookingRepository = bookingRepository;
        this.paymentProvider = paymentProvider;
        this.clock = clock;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    void onPriceReduced(BookingPriceReducedEvent event) {
        refundExcess(event.bookingId(), event.newTotal());
    }

    /** @return the row created, or empty when nothing needs to go back. Public so a test can drive it. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Optional<PaymentPartialRefund> refundExcess(UUID bookingId, BigDecimal newTotal) {
        Payment payment = paymentRepository.findByBookingId(bookingId)
                .filter(p -> p.getStatus() == PaymentStatus.SUCCEEDED).orElse(null);
        if (payment == null) {
            return Optional.empty();
        }
        BigDecimal netPaid = payment.getAmount().subtract(refundRepository.totalForPayment(payment.getId()));
        BigDecimal excess = netPaid.subtract(newTotal);
        if (excess.signum() <= 0) {
            return Optional.empty();
        }
        Optional<BusinessPayout> payout = payoutRepository.findByPaymentId(payment.getId());
        if (payout.isPresent() && (payout.get().getStatus() == BusinessPayoutStatus.PROCESSING
                || payout.get().getStatus() == BusinessPayoutStatus.PAID)) {
            log.warn("Booking {} price reduced but payment {} is already settled — {} needs manual reconciliation",
                    bookingId, payment.getId(), excess);
            return Optional.empty();
        }
        BigDecimal rate = allocationRepository.findByPaymentId(payment.getId()).map(PaymentAllocation::getCommissionRate)
                .orElse(BigDecimal.ZERO);
        int scale = Math.max(Currency.getInstance(payment.getCurrency().toUpperCase(Locale.ROOT))
                .getDefaultFractionDigits(), 0);
        BigDecimal feeReturned = excess.multiply(rate).setScale(scale, RoundingMode.HALF_UP);

        PaymentPartialRefund refund = refundRepository.save(new PaymentPartialRefund(payment.getId(), bookingId,
                excess, payment.getCurrency(), feeReturned, clock.instant()));
        attempt(refund, payment);
        return Optional.of(refund);
    }

    /** Retries rows whose provider call failed (or never completed). */
    @Scheduled(fixedDelay = 600_000)
    void retryDue() {
        List<PaymentPartialRefund> due = refundRepository.findByStatusNot(PaymentPartialRefund.Status.REFUNDED).stream()
                .filter(PaymentPartialRefund::isRetryable).toList();
        for (PaymentPartialRefund row : due) {
            try {
                retry(row.getId());
            } catch (RuntimeException e) {
                log.warn("Retrying partial refund {} failed", row.getId(), e);
            }
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void retry(UUID refundId) {
        PaymentPartialRefund refund = refundRepository.findById(refundId).orElse(null);
        if (refund == null || !refund.isRetryable()) {
            return;
        }
        Payment payment = paymentRepository.findById(refund.getPaymentId()).orElse(null);
        if (payment != null && payment.getStatus() == PaymentStatus.SUCCEEDED) {
            attempt(refund, payment);
        }
    }

    private void attempt(PaymentPartialRefund refund, Payment payment) {
        Instant now = clock.instant();
        PaymentProvider.RefundResult result;
        try {
            result = paymentProvider.refund(payment.getId(), payment.getProviderReference(), refund.getAmount());
        } catch (RuntimeException e) {
            result = new PaymentProvider.RefundResult(false, "Provider error: " + e.getMessage());
        }
        if (!result.succeeded()) {
            refund.markFailed(result.failureReason(), now);
            refundRepository.save(refund);
            return;
        }
        refund.markRefunded(now);
        refundRepository.save(refund);
        Booking booking = bookingRepository.findById(refund.getBookingId()).orElse(null);
        if (booking != null) {
            booking.recordRefund(refund.getAmount());
            bookingRepository.save(booking);
        }
    }
}
