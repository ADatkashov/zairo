package com.zairo.factory.subscriptions;

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
 * One row per billing-period charge attempt — this entity's id is the
 * idempotency key handed to {@code PaymentProvider.charge(...)}, exactly the
 * same guarantee {@code payments.Payment} already relies on (see
 * {@code PaymentProvider}'s own doc comment). Not a reuse of {@code Payment}
 * itself: that entity's {@code bookingId} column is {@code not null unique}
 * — structurally 1:1 with a booking, not reusable for a recurring
 * subscription charge.
 */
@Entity
@Table(name = "subscription_charge")
public class SubscriptionCharge {

    @Id
    private UUID id;

    @Column(name = "subscription_id", nullable = false)
    private UUID subscriptionId;

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "amount", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SubscriptionChargeStatus status;

    @Column(name = "provider_reference")
    private String providerReference;

    @Column(name = "failure_reason")
    private String failureReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected SubscriptionCharge() {
    }

    public SubscriptionCharge(UUID id, UUID subscriptionId, BigDecimal amount, String currency, Instant createdAt) {
        this.id = id;
        this.subscriptionId = subscriptionId;
        this.amount = new Money(amount, currency);
        this.status = SubscriptionChargeStatus.PENDING;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getSubscriptionId() {
        return subscriptionId;
    }

    public BigDecimal getAmount() {
        return amount.amount();
    }

    public String getCurrency() {
        return amount.currencyCode();
    }

    public SubscriptionChargeStatus getStatus() {
        return status;
    }

    public String getFailureReason() {
        return failureReason;
    }

    void markSucceeded(String providerReference, Instant now) {
        this.status = SubscriptionChargeStatus.SUCCEEDED;
        this.providerReference = providerReference;
        this.updatedAt = now;
    }

    void markFailed(String failureReason, Instant now) {
        this.status = SubscriptionChargeStatus.FAILED;
        this.failureReason = failureReason;
        this.updatedAt = now;
    }
}
