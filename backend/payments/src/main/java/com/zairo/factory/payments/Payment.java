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
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.util.Assert;

/**
 * {@code providerReference} holds the provider's own payment id — Freedom
 * Pay's {@code pg_payment_id}, the mock's synthetic {@code mock_pi_...} —
 * see {@code PaymentProvider} for why this is behind a port interface
 * rather than calling a payment SDK directly here.
 */
@Entity
@Table(name = "payment")
public class Payment {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false)
    private UUID bookingId;

    /** How this payment was made */
    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method", nullable = false)
    private PaymentMethod paymentMethod;

    /**
     * Was two independent columns (amount + currency); now one Money value
     * type, kept on the same column names via @AttributeOverrides — see
     * V17__money_value_type.sql. Always the booking's own currency (see
     * PaymentsService.createPayment), never independently configured.
     */
    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "amount", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentStatus status;

    /** Which PaymentProvider implementation actually handled this row — see PaymentProviderName's own doc comment. */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentProviderName provider;

    /**
     * Sent to the provider as its idempotency key on every createPayment/
     * createRecurringPayment call (Freedom Pay's {@code pg_idempotency_key}).
     * Defaults to {@link #id} at construction — kept as its own column
     * rather than always deriving it from {@code id}, so a future case
     * that needs a fresh key for the same payment row (not needed today)
     * doesn't require a schema change.
     */
    @Column(name = "idempotency_key", nullable = false)
    private UUID idempotencyKey;

    @Column(name = "provider_reference")
    private String providerReference;

    /** Raw status string from the provider's own vocabulary (e.g. Freedom Pay's pg_status) — audit/debugging only, never branched on. */
    @Column(name = "provider_status")
    private String providerStatus;

    /** Set while PENDING and a real (redirect-based) provider is in use — where the customer completes payment. */
    @Column(name = "checkout_url")
    private String checkoutUrl;

    @Column(name = "failure_reason")
    private String failureReason;

    /** Set only when a refund attempt fails; cleared on a subsequent success — see {@link #markRefundFailed}. */
    @Column(name = "refund_failure_reason")
    private String refundFailureReason;

    /** Incremented on every failed refund attempt — never reset, even after an eventual success (a historical count). */
    @Column(name = "refund_attempts", nullable = false)
    private int refundAttempts;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** Started so that the card used is saved once the payment succeeds (see SavedCardService). */
    @Column(name = "save_card", nullable = false)
    private boolean saveCard;

    /** Optimistic lock — guards against two concurrent webhook deliveries for the same payment double-processing it. */
    @Version
    private int version;

    protected Payment() {
    }

    public Payment(UUID id, UUID bookingId, BigDecimal amount, String currency, PaymentProviderName provider,
            Instant createdAt) {
        this(id, bookingId, amount, currency, provider, PaymentMethod.ONLINE, createdAt);
    }

    public Payment(UUID id, UUID bookingId, BigDecimal amount, String currency, PaymentProviderName provider,
            PaymentMethod paymentMethod, Instant createdAt) {
        Assert.notNull(paymentMethod, "paymentMethod must not be null");
        this.id = id;
        this.bookingId = bookingId;
        this.amount = new Money(amount, currency);
        this.status = PaymentStatus.CREATED;
        this.provider = provider;
        this.paymentMethod = paymentMethod;
        this.idempotencyKey = id;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public UUID getId() {
        return id;
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

    public PaymentStatus getStatus() {
        return status;
    }

    public PaymentProviderName getProvider() {
        return provider;
    }

    public UUID getIdempotencyKey() {
        return idempotencyKey;
    }

    public String getProviderReference() {
        return providerReference;
    }

    public String getProviderStatus() {
        return providerStatus;
    }

    public String getCheckoutUrl() {
        return checkoutUrl;
    }

    public String getFailureReason() {
        return failureReason;
    }

    public PaymentMethod getPaymentMethod() {
        return paymentMethod;
    }

    public String getRefundFailureReason() {
        return refundFailureReason;
    }

    public int getRefundAttempts() {
        return refundAttempts;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public boolean isSaveCard() {
        return saveCard;
    }

    void setSaveCard(boolean saveCard) {
        this.saveCard = saveCard;
    }

    /** Provider accepted the request but hasn't confirmed the outcome yet — a real (redirect-based) provider's normal path. */
    void markPending(String providerPaymentId, String checkoutUrl, Instant now) {
        this.status = PaymentStatus.PENDING;
        this.providerReference = providerPaymentId;
        this.checkoutUrl = checkoutUrl;
        this.updatedAt = now;
    }

    void markSucceeded(String providerReference, Instant now) {
        this.status = PaymentStatus.SUCCEEDED;
        this.providerReference = providerReference;
        this.checkoutUrl = null;
        this.updatedAt = now;
    }

    void markFailed(String failureReason, Instant now) {
        this.status = PaymentStatus.FAILED;
        this.failureReason = failureReason;
        this.checkoutUrl = null;
        this.updatedAt = now;
    }

    /**
     * A durable {@link PaymentRefundRequest} now exists for this payment --
     * see {@code BookingCancelledPaymentListener}/{@code
     * PaymentWebhookProcessor}'s race-F handling. Doubles as a concurrency
     * guard: {@code PaymentsService#refundPayment}'s own guard only accepts
     * SUCCEEDED or REFUND_FAILED, so a payment sitting REFUND_PENDING can't
     * also be picked up by the manual admin retry endpoint while the
     * automatic outbox worker owns it -- the two paths hand off cleanly
     * instead of racing (the worker's terminal FAILED state moves this to
     * REFUND_FAILED, which is exactly when the manual path becomes valid
     * again).
     */
    void markRefundPending(Instant now) {
        this.status = PaymentStatus.REFUND_PENDING;
        this.updatedAt = now;
    }

    void markRefunded(Instant now) {
        this.status = PaymentStatus.REFUNDED;
        this.refundFailureReason = null;
        this.updatedAt = now;
    }

    /**
     * A refund attempt failed — status moves to REFUND_FAILED (not left at
     * SUCCEEDED) so it's directly queryable, not just inferrable from a
     * non-null refundFailureReason. Refundable from this state too — see
     * PaymentsService.refundPayment's guard.
     */
    void markRefundFailed(String reason, Instant now) {
        this.status = PaymentStatus.REFUND_FAILED;
        this.refundFailureReason = reason;
        this.refundAttempts += 1;
        this.updatedAt = now;
    }
}
