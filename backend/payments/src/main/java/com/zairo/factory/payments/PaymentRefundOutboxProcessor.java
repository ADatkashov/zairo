package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.payments.PaymentRefundOutboxItemProcessor.ClaimOutcome;
import com.zairo.factory.payments.PaymentRefundOutboxItemProcessor.Claimed;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * The durable, retrying half of the booking-cancellation refund flow -- see
 * {@link PaymentRefundRequest}'s own doc comment for the full design, and
 * {@code loyalty.LoyaltyOutboxProcessor} for the sibling this mirrors the
 * shape of (two triggers into one {@link #processOne} path: an eager
 * AFTER_COMMIT nudge for the common case, a scheduled sweep as the
 * durability backstop).
 *
 * <p>The one real difference from loyalty's outbox: {@link #processOne}
 * itself is deliberately <b>not</b> {@code @Transactional} at all. {@link
 * PaymentRefundOutboxItemProcessor#claim} commits before the {@link
 * PaymentProvider#refund} call below even starts, and {@code applySuccess}/
 * {@code applyFailure} open their own fresh transaction afterward -- the
 * provider call itself never runs inside a database transaction (see that
 * class's own doc comment for why).
 */
@Component
class PaymentRefundOutboxProcessor {

    private static final Logger log = LoggerFactory.getLogger(PaymentRefundOutboxProcessor.class);
    private static final int PAGE_SIZE = 200;

    private final PaymentRefundRequestRepository refundRequestRepository;
    private final PaymentRefundOutboxItemProcessor itemProcessor;
    private final PaymentProvider paymentProvider;
    private final Clock clock;

    PaymentRefundOutboxProcessor(PaymentRefundRequestRepository refundRequestRepository,
            PaymentRefundOutboxItemProcessor itemProcessor, PaymentProvider paymentProvider, Clock clock) {
        this.refundRequestRepository = refundRequestRepository;
        this.itemProcessor = itemProcessor;
        this.paymentProvider = paymentProvider;
        this.clock = clock;
    }

    /**
     * The eager, near-immediate fast path -- fires right after the
     * transaction that created (or made claimable again) the row commits.
     * Purely a latency optimization: {@link #run}'s next sweep would catch
     * this row regardless, so a failure here is never a second place
     * durability depends on.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onRefundRequestReady(PaymentRefundRequestReady ready) {
        processOne(ready.refundRequestId());
    }

    @Scheduled(fixedDelay = 15_000)
    void run() {
        Instant now = clock.instant();
        Instant staleBefore = now.minus(PaymentRefundRequest.STALE_PROCESSING_THRESHOLD);
        List<PaymentRefundRequest> page;
        boolean progressed;
        do {
            page = refundRequestRepository.findDue(now, staleBefore, PageRequest.of(0, PAGE_SIZE));
            progressed = false;
            for (PaymentRefundRequest request : page) {
                progressed |= processOne(request.getId());
            }
        } while (!page.isEmpty() && progressed);
    }

    /** @return true if this call actually claimed and resolved the row (false if it was already claimed/not due elsewhere). */
    private boolean processOne(UUID id) {
        ClaimOutcome outcome = itemProcessor.claim(id);
        if (!(outcome instanceof Claimed claimed)) {
            return false;
        }

        PaymentRefundOutboxItemProcessor.ClaimedRefund refund = claimed.refund();
        boolean succeeded;
        String failureReason;
        try {
            PaymentProvider.RefundResult result = paymentProvider.refund(refund.paymentId(),
                    refund.providerReference(), refund.amount());
            succeeded = result.succeeded();
            failureReason = result.failureReason();
        } catch (RuntimeException e) {
            // Thrown before any structured response came back -- genuinely
            // ambiguous (see PaymentRefundRequest's class doc comment and
            // ADR-0006's "Durable Refund Outbox" section: this provider's
            // refund call carries no confirmed idempotency key of its own,
            // so this codebase cannot safely tell "definitely not refunded"
            // apart from "refunded, but the response was lost" here).
            // Treated the same as a confirmed provider failure: retry up to
            // MAX_ATTEMPTS rather than silently giving up on a genuinely
            // uncertain outcome.
            succeeded = false;
            failureReason = "Payment provider error: " + e.getMessage();
            log.warn("Freedom Pay refund threw for payment refund request {} (payment {}): {}", id,
                    refund.paymentId(), e.getMessage(), e);
        }

        if (succeeded) {
            itemProcessor.applySuccess(id);
        } else {
            itemProcessor.applyFailure(id, failureReason);
        }
        return true;
    }
}
