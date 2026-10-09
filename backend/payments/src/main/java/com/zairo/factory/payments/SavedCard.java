package com.zairo.factory.payments;

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
 * A customer's saved card: the provider's recurring profile plus display-only
 * details. Only the last four digits and the brand are kept — never a full
 * card number.
 */
@Entity
@Table(name = "saved_card")
public class SavedCard {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

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

    protected SavedCard() {
    }

    public SavedCard(UUID id, UUID userId, PaymentProviderName provider, String recurringProfileId, String cardLast4,
            String cardBrand, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.provider = provider;
        this.recurringProfileId = recurringProfileId;
        this.cardLast4 = cardLast4;
        this.cardBrand = cardBrand;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
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
