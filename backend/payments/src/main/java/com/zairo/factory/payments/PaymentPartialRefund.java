package com.zairo.factory.payments;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Part of a payment returned to the customer while the payment itself stays {@link PaymentStatus#SUCCEEDED} (the
 * booking moved to a cheaper worker). A row exists from the moment the amount is decided, so a failed provider call is
 * a durable fact that {@link PaymentPartialRefundService} retries rather than money silently owed.
 */
@Entity
@Table(name = "payment_partial_refund")
public class PaymentPartialRefund {

    public enum Status {
        PENDING, REFUNDED, FAILED
    }

    static final int MAX_ATTEMPTS = 8;

    @Id
    private UUID id;

    @Column(name = "payment_id", nullable = false, updatable = false)
    private UUID paymentId;

    @Column(name = "booking_id", nullable = false, updatable = false)
    private UUID bookingId;

    @Column(nullable = false, updatable = false, precision = 19, scale = 2)
    private BigDecimal amount;

    @Column(nullable = false, updatable = false, length = 3)
    private String currency;

    /** The part of {@link #amount} that was ZAIRO's commission — the business share removed is {@code amount - this}. */
    @Column(name = "platform_fee_returned", nullable = false, updatable = false, precision = 19, scale = 2)
    private BigDecimal platformFeeReturned;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status;

    @Column(nullable = false)
    private int attempts;

    @Column(name = "last_error", length = 1000)
    private String lastError;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PaymentPartialRefund() {
    }

    PaymentPartialRefund(UUID paymentId, UUID bookingId, BigDecimal amount, String currency,
            BigDecimal platformFeeReturned, Instant now) {
        this.id = UUID.randomUUID();
        this.paymentId = paymentId;
        this.bookingId = bookingId;
        this.amount = amount;
        this.currency = currency;
        this.platformFeeReturned = platformFeeReturned;
        this.status = Status.PENDING;
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
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public BigDecimal getPlatformFeeReturned() {
        return platformFeeReturned;
    }

    public Status getStatus() {
        return status;
    }

    public int getAttempts() {
        return attempts;
    }

    public String getLastError() {
        return lastError;
    }

    boolean isRetryable() {
        return status != Status.REFUNDED && attempts < MAX_ATTEMPTS;
    }

    void markRefunded(Instant now) {
        this.status = Status.REFUNDED;
        this.lastError = null;
        this.updatedAt = now;
    }

    void markFailed(String error, Instant now) {
        this.status = Status.FAILED;
        this.attempts += 1;
        this.lastError = error == null ? null : error.substring(0, Math.min(error.length(), 1000));
        this.updatedAt = now;
    }
}
