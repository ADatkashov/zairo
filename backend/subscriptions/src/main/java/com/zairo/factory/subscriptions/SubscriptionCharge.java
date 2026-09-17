package com.zairo.factory.subscriptions;

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
import java.time.Instant;
import java.util.UUID;

/**
 * One row per billing-period charge attempt — this entity's id is the
 * idempotency key handed to {@code PaymentProvider.createRecurringPayment}/
 * {@code chargeRecurring}, exactly the same guarantee {@code
 * payments.Payment} already relies on (see {@code PaymentProvider}'s own
 * doc comment). Not a reuse of {@code Payment} itself: that entity's
 * {@code bookingId} column is {@code not null unique} — structurally 1:1
 * with a booking, not reusable for a recurring subscription charge.
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

    /** Which PaymentProvider implementation handled this charge — see payments.Payment's identical field. */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentProviderName provider;

    /**
     * Freedom Pay's {@code pg_recurring_profile_id} — returned only on the
     * <em>first</em> (upgrade) charge's webhook, once a recurring profile
     * exists (see {@code SubscriptionService.upgradeToPro}). Carried
     * forward onto every later renewal charge row so {@code
     * SubscriptionRenewalService.chargeForRenewal} knows which profile to
     * charge — see ADR-0006's Subscription Architecture.
     */
    @Column(name = "recurring_profile_id")
    private String recurringProfileId;

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

    public SubscriptionCharge(UUID id, UUID subscriptionId, BigDecimal amount, String currency,
            PaymentProviderName provider, String recurringProfileId, Instant createdAt) {
        this.id = id;
        this.subscriptionId = subscriptionId;
        this.amount = new Money(amount, currency);
        this.status = SubscriptionChargeStatus.PENDING;
        this.provider = provider;
        this.recurringProfileId = recurringProfileId;
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

    public PaymentProviderName getProvider() {
        return provider;
    }

    public String getRecurringProfileId() {
        return recurringProfileId;
    }

    public String getProviderReference() {
        return providerReference;
    }

    public String getFailureReason() {
        return failureReason;
    }

    /** The Billing screen's invoice history (v2 design audit) sorts by this. */
    public Instant getCreatedAt() {
        return createdAt;
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

    /** Set once a webhook confirms the recurring profile Freedom Pay created for this (first, upgrade) charge. */
    void assignRecurringProfileId(String recurringProfileId, Instant now) {
        this.recurringProfileId = recurringProfileId;
        this.updatedAt = now;
    }
}
