package com.zairo.factory.payments;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * The per-item, transactional half of {@link PaymentRefundOutboxProcessor}'s
 * sweep -- split into its own bean for the same reason {@code
 * loyalty.LoyaltyOutboxItemProcessor} is: Spring's proxy-based AOP only
 * intercepts calls that arrive <em>through</em> the proxy, so {@code
 * @Transactional}/{@code REQUIRES_NEW} would silently do nothing if these
 * methods were called via {@code this.} from inside the orchestrator.
 *
 * <p>Every method here is its own short {@code REQUIRES_NEW} transaction,
 * deliberately never wrapping the actual {@code PaymentProvider#refund}
 * call -- that HTTP call happens in the orchestrator, <em>between</em>
 * {@link #claim} committing and {@link #applySuccess}/{@link #applyFailure}
 * starting. A network call inside an open database transaction would hold
 * a connection (and, more importantly here, a row lock) for as long as
 * Freedom Pay takes to respond -- exactly the anti-pattern this design
 * avoids.
 */
@Component
class PaymentRefundOutboxItemProcessor {

    private static final Logger log = LoggerFactory.getLogger(PaymentRefundOutboxItemProcessor.class);

    private final PaymentRefundRequestRepository refundRequestRepository;
    private final PaymentRepository paymentRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    PaymentRefundOutboxItemProcessor(PaymentRefundRequestRepository refundRequestRepository,
            PaymentRepository paymentRepository, ApplicationEventPublisher eventPublisher, Clock clock) {
        this.refundRequestRepository = refundRequestRepository;
        this.paymentRepository = paymentRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    /** What the provider call needs — a snapshot taken under the row lock, so the caller never re-reads mutable state. */
    record ClaimedRefund(UUID paymentId, String providerReference, BigDecimal amount, String currency) {
    }

    sealed interface ClaimOutcome permits Claimed, NotClaimable {
    }

    record Claimed(ClaimedRefund refund) implements ClaimOutcome {
    }

    record NotClaimable() implements ClaimOutcome {
    }

    /**
     * Takes the row lock, re-checks {@link PaymentRefundRequest#isClaimable}
     * under it (the sweep query that found this id is a best-effort
     * candidate list, not itself authoritative -- see that repository
     * method's own doc comment), and transitions PENDING/RETRY/stale-
     * PROCESSING to PROCESSING. Two concurrent workers (or an eager
     * AFTER_COMMIT nudge racing the next scheduled sweep for the same row)
     * both calling this only ever let one of them observe a claimable
     * status before the other's lock acquisition blocks behind the first's
     * commit -- by the time the second gets the lock, the row is already
     * PROCESSING and not stale, so it correctly sees {@link NotClaimable}.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    ClaimOutcome claim(UUID id) {
        Instant now = clock.instant();
        PaymentRefundRequest request = refundRequestRepository.lockById(id).orElse(null);
        if (request == null || !request.isClaimable(now)) {
            return new NotClaimable();
        }
        ClaimedRefund snapshot = new ClaimedRefund(request.getPaymentId(), request.getProviderReference(),
                request.getAmount(), request.getCurrency());
        request.markProcessing(now);
        refundRequestRepository.save(request);
        return new Claimed(snapshot);
    }

    /**
     * The provider confirmed the refund. Marks both the request row and the
     * {@link Payment} itself terminal, and publishes the same {@link
     * PaymentRefundedEvent} {@code PaymentsService#refundPayment} always
     * has — loyalty's refund-reversal listener and the customer-facing
     * "Refund processed" email both already react to it, unchanged.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    void applySuccess(UUID id) {
        Instant now = clock.instant();
        PaymentRefundRequest request = refundRequestRepository.lockById(id).orElse(null);
        if (request == null || request.getStatus() != PaymentRefundRequestStatus.PROCESSING) {
            return; // already resolved by a previous pass -- SUCCEEDED must stay terminal, never re-applied
        }
        request.markSucceeded(now);
        refundRequestRepository.save(request);

        Payment payment = paymentRepository.findById(request.getPaymentId()).orElse(null);
        if (payment == null) {
            log.error("Payment refund request {} succeeded but payment {} no longer exists", id,
                    request.getPaymentId());
            return;
        }
        payment.markRefunded(now);
        Payment refunded = paymentRepository.save(payment);
        eventPublisher.publishEvent(new PaymentRefundedEvent(refunded.getId(), refunded.getBookingId(),
                refunded.getAmount(), refunded.getCurrency()));
    }

    /**
     * Records a failed attempt and either schedules a backoff retry or, past
     * {@link PaymentRefundRequest#MAX_ATTEMPTS}, dead-letters permanently —
     * mirroring {@code Payment.markRefundFailed} onto the payment itself too
     * in the dead-letter case, so a refund that gave up automatically shows
     * up in the existing {@code PaymentAdminController#failedRefunds} list
     * (and its own {@code POST /payments/{id}/refund} manual retry) exactly
     * the same as one that failed via that endpoint directly.
     *
     * @return true if this attempt dead-lettered the row (FAILED)
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    boolean applyFailure(UUID id, String reason) {
        Instant now = clock.instant();
        PaymentRefundRequest request = refundRequestRepository.lockById(id).orElse(null);
        if (request == null || request.getStatus() != PaymentRefundRequestStatus.PROCESSING) {
            return true; // already resolved by a previous pass -- nothing left to record
        }
        request.recordFailure(reason, now);
        boolean deadLettered = request.getAttempts() >= PaymentRefundRequest.MAX_ATTEMPTS;
        if (deadLettered) {
            request.markFailedPermanently(now);
            log.error("Payment refund request {} (payment {}) permanently failed after {} attempts, last error: {}",
                    id, request.getPaymentId(), request.getAttempts(), reason);
            paymentRepository.findById(request.getPaymentId()).ifPresentOrElse(payment -> {
                payment.markRefundFailed(reason, now);
                paymentRepository.save(payment);
            }, () -> log.error("Payment refund request {} dead-lettered but payment {} no longer exists", id,
                    request.getPaymentId()));
        }
        refundRequestRepository.save(request);
        return deadLettered;
    }
}
