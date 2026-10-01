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
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * The business's (Provider's) share of one booking's payment, tracked from
 * the moment the service is actually delivered to the moment the money
 * really leaves ZAIRO for the business — see
 * {@code docs/adr/0007-marketplace-commission-and-settlement.md}.
 *
 * <p><b>Created only once the booking is {@code COMPLETED}</b> (see
 * {@code BusinessPayoutService.onBookingCompleted}), never at payment time —
 * this is the task's own "Business receives money after successful
 * completion of service" requirement, and the reason a booking that's
 * refunded/cancelled before completion never gets a row here at all.
 *
 * <p><b>Not a Freedom Pay-confirmed automatic settlement</b> — see
 * {@link #providerReference}'s own doc comment and ADR-0007: this row
 * tracks ZAIRO's own settlement obligation and its outcome, however the
 * money is actually moved (today: a platform admin performs a manual bank
 * transfer and records it here).
 */
@Entity
@Table(name = "business_payout")
public class BusinessPayout {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false, unique = true)
    private UUID bookingId;

    @Column(name = "payment_id", nullable = false)
    private UUID paymentId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "amount", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BusinessPayoutStatus status;

    /**
     * Whatever actually moved the money — a manual bank transfer reference
     * today (see this class's own doc comment); never validated for shape,
     * never a Freedom Pay payout id today (that API isn't confirmed —
     * ADR-0007, Open Questions).
     */
    @Column(name = "provider_reference")
    private String providerReference;

    @Column(name = "failure_reason")
    private String failureReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "settled_at")
    private Instant settledAt;

    /** Guards against two concurrent admin actions (or an admin action racing a reconciliation job) double-processing one payout. */
    @Version
    private int version;

    protected BusinessPayout() {
    }

    public BusinessPayout(UUID id, UUID bookingId, UUID paymentId, UUID providerId, BigDecimal amount,
            String currency, Instant createdAt) {
        this.id = id;
        this.bookingId = bookingId;
        this.paymentId = paymentId;
        this.providerId = providerId;
        this.amount = new Money(amount, currency);
        this.status = BusinessPayoutStatus.PAYABLE;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getPaymentId() {
        return paymentId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public BigDecimal getAmount() {
        return amount.amount();
    }

    public String getCurrency() {
        return amount.currencyCode();
    }

    public BusinessPayoutStatus getStatus() {
        return status;
    }

    public String getProviderReference() {
        return providerReference;
    }

    public String getFailureReason() {
        return failureReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getSettledAt() {
        return settledAt;
    }

    /** PAYABLE/FAILED -> PROCESSING only — see {@link BusinessPayoutStatus}'s own doc comment for the allowed graph. */
    void markProcessing(Instant now) {
        requireNotTerminal();
        this.status = BusinessPayoutStatus.PROCESSING;
        this.updatedAt = now;
    }

    /** Any non-terminal status -> PAID — see {@link #requireNotTerminal}. */
    void markPaid(String providerReference, Instant now) {
        requireNotTerminal();
        this.status = BusinessPayoutStatus.PAID;
        this.providerReference = providerReference;
        this.failureReason = null;
        this.settledAt = now;
        this.updatedAt = now;
    }

    /** Any non-terminal status -> FAILED — retriable, same as {@code Payment.markRefundFailed}. */
    void markFailed(String reason, Instant now) {
        requireNotTerminal();
        this.status = BusinessPayoutStatus.FAILED;
        this.failureReason = reason;
        this.updatedAt = now;
    }

    private void requireNotTerminal() {
        if (status == BusinessPayoutStatus.PAID) {
            throw new PaymentConflictException("Payout is already PAID and is terminal: " + id);
        }
    }
}
