package com.zairo.factory.subscriptions;

import com.zairo.factory.paymentprovider.PaymentProviderName;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * The card a subscription is renewed with: the provider's recurring profile
 * plus display-only card details. Only the last four digits and the brand
 * are ever stored — never a full card number.
 */
@Entity
@Table(name = "subscription_payment_method")
public class SubscriptionPaymentMethod {

    @Id
    @Column(name = "subscription_id")
    private UUID subscriptionId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentProviderName provider;

    @Column(name = "recurring_profile_id", nullable = false)
    private String recurringProfileId;

    @Column(name = "card_last4")
    private String cardLast4;

    @Column(name = "card_brand")
    private String cardBrand;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected SubscriptionPaymentMethod() {
    }

    public SubscriptionPaymentMethod(UUID subscriptionId, PaymentProviderName provider, String recurringProfileId,
            String cardLast4, String cardBrand, Instant now) {
        this.subscriptionId = subscriptionId;
        this.provider = provider;
        this.recurringProfileId = recurringProfileId;
        this.cardLast4 = cardLast4;
        this.cardBrand = cardBrand;
        this.createdAt = now;
        this.updatedAt = now;
    }

    /** A new checkout replaces the card; details the provider did not report keep their previous value only for the same profile. */
    void replaceWith(PaymentProviderName provider, String recurringProfileId, String cardLast4, String cardBrand,
            Instant now) {
        boolean sameProfile = recurringProfileId.equals(this.recurringProfileId);
        this.provider = provider;
        this.recurringProfileId = recurringProfileId;
        this.cardLast4 = cardLast4 != null || !sameProfile ? cardLast4 : this.cardLast4;
        this.cardBrand = cardBrand != null || !sameProfile ? cardBrand : this.cardBrand;
        this.updatedAt = now;
    }

    public UUID getSubscriptionId() {
        return subscriptionId;
    }

    public PaymentProviderName getProvider() {
        return provider;
    }

    public String getRecurringProfileId() {
        return recurringProfileId;
    }

    public String getCardLast4() {
        return cardLast4;
    }

    public String getCardBrand() {
        return cardBrand;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
