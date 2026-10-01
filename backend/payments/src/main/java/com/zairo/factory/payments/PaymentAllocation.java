package com.zairo.factory.payments;

import com.zairo.factory.money.Money;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * How a {@link PaymentStatus#SUCCEEDED} {@link Payment} splits between the
 * business (Provider) and ZAIRO's own marketplace commission — see
 * {@link CommissionCalculator} for how the split is computed and
 * {@code docs/adr/0007-marketplace-commission-and-settlement.md} for why
 * this is its own row rather than two extra columns on {@code Payment}.
 *
 * <p>Created exactly once per payment, the moment it succeeds (see
 * {@code PaymentAllocationService}) — never recomputed afterward, even if
 * {@code payment.commission.rate} changes later. A refund does not delete
 * or mutate this row: it stays the historical record of what the payment
 * was worth when it succeeded, which {@code BusinessPayoutService} and
 * reconciliation both rely on staying fixed.
 *
 * <p><b>Invariant enforced at construction, not just assumed</b>:
 * {@code businessAmount + platformFee == payment amount}, exactly, in the
 * payment's own currency — see the constructor. A commission calculation
 * that can't satisfy this is a bug, not a value to silently store.
 */
@Entity
@Table(name = "payment_allocation")
public class PaymentAllocation {

    @Id
    @Column(name = "payment_id")
    private java.util.UUID paymentId;

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "business_amount", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money businessAmount;

    @Column(name = "platform_fee", nullable = false)
    private BigDecimal platformFee;

    /** The rate actually applied — see this class's own doc comment on why it's snapshotted, not read live from config. */
    @Column(name = "commission_rate", nullable = false)
    private BigDecimal commissionRate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected PaymentAllocation() {
    }

    public PaymentAllocation(java.util.UUID paymentId, BigDecimal totalAmount, BigDecimal businessAmount,
            BigDecimal platformFee, String currency, BigDecimal commissionRate, Instant createdAt) {
        if (businessAmount.add(platformFee).compareTo(totalAmount) != 0) {
            // Fail-fast (Phase 5's "amount mismatch detection") — a split
            // that doesn't reconstitute the original payment amount exactly
            // is never persisted, not even as a "close enough" value.
            throw new IllegalStateException("Commission split does not add up: businessAmount=" + businessAmount
                    + " + platformFee=" + platformFee + " != totalAmount=" + totalAmount);
        }
        if (businessAmount.signum() < 0 || platformFee.signum() < 0) {
            throw new IllegalArgumentException("businessAmount/platformFee must not be negative: businessAmount="
                    + businessAmount + " platformFee=" + platformFee);
        }
        this.paymentId = paymentId;
        this.businessAmount = new Money(businessAmount, currency);
        this.platformFee = platformFee;
        this.commissionRate = commissionRate;
        this.createdAt = createdAt;
    }

    public java.util.UUID getPaymentId() {
        return paymentId;
    }

    public BigDecimal getBusinessAmount() {
        return businessAmount.amount();
    }

    public String getCurrency() {
        return businessAmount.currencyCode();
    }

    public BigDecimal getPlatformFee() {
        return platformFee;
    }

    public BigDecimal getCommissionRate() {
        return commissionRate;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
