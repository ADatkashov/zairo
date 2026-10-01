package com.zairo.factory.payments;

import com.zairo.factory.money.Money;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

/**
 * A durable record of one payment that still needs to be refunded back to
 * the customer -- the payments-module counterpart of {@code
 * loyalty.LoyaltyOutboxEvent}, same durability shape, different semantics:
 * loyalty's earning computation is idempotent by reference and safe to
 * reprocess freely, but a refund is a real external money movement that
 * must never be double-executed, so this row is also the thing {@link
 * PaymentRefundRequestRepository#lockById} takes a row lock on to keep
 * concurrent workers from ever both calling {@code PaymentProvider#refund}
 * for the same row at once (see {@code PaymentRefundOutboxItemProcessor}).
 *
 * <p>Written in the SAME transaction as the booking-cancellation (or
 * already-cancelled-booking webhook) write that means this payment needs
 * refunding -- see {@code BookingCancelledPaymentListener} and {@code
 * PaymentWebhookProcessor}'s race-F handling, both plain (non-AFTER_COMMIT)
 * listeners for exactly this reason: a crash right after commit can never
 * lose this row the way the old best-effort {@code
 * BookingCancelledPaymentListener} (AFTER_COMMIT + REQUIRES_NEW, calling
 * {@code PaymentsService#refundPayment} directly, catching and only logging
 * any failure) could.
 *
 * <p>{@code paymentId} is unique -- a payment can have at most one refund
 * request, ever. This is the idempotency guarantee against a duplicate
 * cancellation event or a duplicate webhook delivery trying to refund the
 * same payment twice: the second insert attempt hits the database
 * constraint (see V63's migration comment), not application logic.
 */
@Entity
@Table(name = "payment_refund_request")
public class PaymentRefundRequest {

    static final int MAX_ATTEMPTS = 8;

    /**
     * A row left PROCESSING longer than this was almost certainly abandoned
     * by a worker that crashed mid-call (application restart during the
     * Freedom Pay call) rather than one still genuinely in flight -- see
     * {@link #isClaimable}. Comfortably longer than {@code
     * FreedomPayHttpClient}'s own 15s request timeout, so a slow-but-alive
     * call is never reclaimed out from under itself.
     */
    static final Duration STALE_PROCESSING_THRESHOLD = Duration.ofMinutes(5);

    @Id
    private UUID id;

    @Column(name = "payment_id", nullable = false, unique = true)
    private UUID paymentId;

    @Column(name = "booking_id", nullable = false)
    private UUID bookingId;

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "amount", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money amount;

    /** Which {@code PaymentProvider} implementation this payment was charged through -- see {@code Payment.provider}. */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentProviderName provider;

    /**
     * Snapshotted from {@code Payment.providerReference} at creation time --
     * the provider's own id for the original charge, which {@code
     * PaymentProvider#refund} needs to know what to refund. A SUCCEEDED
     * payment always has one (see {@code Payment.markSucceeded}), so this is
     * never null for a row that ever gets created.
     */
    @Column(name = "provider_reference", nullable = false)
    private String providerReference;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentRefundRequestStatus status;

    @Column(nullable = false)
    private int attempts;

    /** Null while PENDING (immediately due) or once terminal; set on every RETRY transition -- see {@link #recordFailure}. */
    @Column(name = "next_attempt_at")
    private Instant nextAttemptAt;

    /** Set when claimed into PROCESSING, cleared on any terminal-for-this-attempt transition -- see {@link #isClaimable}. */
    @Column(name = "processing_started_at")
    private Instant processingStartedAt;

    @Column(name = "last_error", length = 1000)
    private String lastError;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PaymentRefundRequest() {
    }

    PaymentRefundRequest(UUID id, UUID paymentId, UUID bookingId, BigDecimal amount, String currency,
            PaymentProviderName provider, String providerReference, Instant now) {
        this.id = id;
        this.paymentId = paymentId;
        this.bookingId = bookingId;
        this.amount = new Money(amount, currency);
        this.provider = provider;
        this.providerReference = providerReference;
        this.status = PaymentRefundRequestStatus.PENDING;
        this.attempts = 0;
        this.nextAttemptAt = now;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getPaymentId() {
        return paymentId;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public BigDecimal getAmount() {
        return amount.amount();
    }

    public String getCurrency() {
        return amount.currencyCode();
    }

    public PaymentProviderName getProvider() {
        return provider;
    }

    public String getProviderReference() {
        return providerReference;
    }

    public PaymentRefundRequestStatus getStatus() {
        return status;
    }

    public int getAttempts() {
        return attempts;
    }

    public Instant getNextAttemptAt() {
        return nextAttemptAt;
    }

    public Instant getProcessingStartedAt() {
        return processingStartedAt;
    }

    public String getLastError() {
        return lastError;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    /**
     * Whether a worker may claim this row right now -- PENDING/RETRY due for
     * another attempt, or PROCESSING but abandoned long enough ago to treat
     * as a crashed worker's leftovers (restart recovery). SUCCEEDED/FAILED
     * are always false -- both terminal, never revisited.
     */
    boolean isClaimable(Instant now) {
        return switch (status) {
            case PENDING, RETRY -> nextAttemptAt == null || !nextAttemptAt.isAfter(now);
            case PROCESSING -> processingStartedAt != null
                    && processingStartedAt.isBefore(now.minus(STALE_PROCESSING_THRESHOLD));
            case SUCCEEDED, FAILED -> false;
        };
    }

    void markProcessing(Instant now) {
        this.status = PaymentRefundRequestStatus.PROCESSING;
        this.processingStartedAt = now;
        this.updatedAt = now;
    }

    /** Terminal -- see class doc comment. No further transition is ever valid after this. */
    void markSucceeded(Instant now) {
        this.status = PaymentRefundRequestStatus.SUCCEEDED;
        this.processingStartedAt = null;
        this.updatedAt = now;
    }

    /**
     * Records one failed attempt and schedules the next one with
     * exponential backoff (30s, 60s, 120s, ... capped at 30 minutes) --
     * deliberately not a flat retry interval like {@code
     * LoyaltyOutboxProcessor}'s 15s sweep: that table's retries are cheap,
     * local, idempotent recomputation; this one is a real network call
     * against an external payment provider, where hammering a transient
     * outage every few seconds helps no one. Caller ({@code
     * PaymentRefundOutboxItemProcessor}) decides whether attempts has now
     * reached {@link #MAX_ATTEMPTS} and should call {@link
     * #markFailedPermanently} instead/in addition.
     */
    void recordFailure(String error, Instant now) {
        this.attempts += 1;
        this.lastError = error == null ? null : error.substring(0, Math.min(error.length(), 1000));
        this.status = PaymentRefundRequestStatus.RETRY;
        this.processingStartedAt = null;
        this.nextAttemptAt = now.plus(backoff(this.attempts));
        this.updatedAt = now;
    }

    /** Terminal -- see class doc comment. Gave up after {@link #MAX_ATTEMPTS}; {@code Payment} moves to REFUND_FAILED too. */
    void markFailedPermanently(Instant now) {
        this.status = PaymentRefundRequestStatus.FAILED;
        this.processingStartedAt = null;
        this.updatedAt = now;
    }

    private static Duration backoff(int attempts) {
        long seconds = 30L << Math.min(attempts - 1, 6); // 30s, 60s, 120s, ..., capped by the min() below at 1920s
        return Duration.ofSeconds(Math.min(seconds, 1800L)); // hard cap: 30 minutes
    }
}
