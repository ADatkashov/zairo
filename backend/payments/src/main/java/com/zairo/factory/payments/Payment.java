package com.zairo.factory.payments;

import com.zairo.factory.money.Money;
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
import java.time.Instant;
import java.util.UUID;

/**
 * {@code providerReference} stands in for a real payment provider's charge/
 * PaymentIntent id (e.g. Stripe's {@code pi_...}) — see PaymentProvider for
 * why this is behind an interface rather than calling a payment SDK
 * directly here.
 */
@Entity
@Table(name = "payment")
public class Payment {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false, unique = true)
    private UUID bookingId;

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

    @Column(name = "provider_reference")
    private String providerReference;

    @Column(name = "failure_reason")
    private String failureReason;

    /** Set only when a refund attempt fails; cleared on a subsequent success — see {@link #markRefundFailed}. */
    @Column(name = "refund_failure_reason")
    private String refundFailureReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Payment() {
    }

    public Payment(UUID id, UUID bookingId, BigDecimal amount, String currency, Instant createdAt) {
        this.id = id;
        this.bookingId = bookingId;
        this.amount = new Money(amount, currency);
        this.status = PaymentStatus.PENDING;
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

    public String getProviderReference() {
        return providerReference;
    }

    public String getFailureReason() {
        return failureReason;
    }

    public String getRefundFailureReason() {
        return refundFailureReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    void markSucceeded(String providerReference, Instant now) {
        this.status = PaymentStatus.SUCCEEDED;
        this.providerReference = providerReference;
        this.updatedAt = now;
    }

    void markFailed(String failureReason, Instant now) {
        this.status = PaymentStatus.FAILED;
        this.failureReason = failureReason;
        this.updatedAt = now;
    }

    void markRefunded(Instant now) {
        this.status = PaymentStatus.REFUNDED;
        this.refundFailureReason = null;
        this.updatedAt = now;
    }

    /** Status stays SUCCEEDED — a failed refund attempt didn't undo the original charge, just failed to reverse it. */
    void markRefundFailed(String reason, Instant now) {
        this.refundFailureReason = reason;
        this.updatedAt = now;
    }
}
