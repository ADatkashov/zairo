package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
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
 * One thing a business's customers can spend points on. {@code serviceId}
 * is a bare, FK-less reference into {@code services.ServiceOffering} (same
 * cross-module convention as everywhere else in this codebase) --
 * meaningful for {@link LoyaltyRewardType#FREE_SERVICE}, optional
 * otherwise. {@link LoyaltyRedemption} snapshots this reward's shape at
 * redemption time, so editing a reward later never rewrites history.
 */
@Entity
@Table(name = "loyalty_reward")
public class LoyaltyReward {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(nullable = false)
    private String name;

    @Column
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LoyaltyRewardType type;

    @Column(name = "points_cost", nullable = false)
    private int pointsCost;

    @Column(name = "discount_amount")
    private BigDecimal discountAmount;

    @Column(name = "discount_currency", length = 3)
    private String discountCurrency;

    @Column(name = "discount_percentage")
    private BigDecimal discountPercentage;

    @Column(name = "service_id")
    private UUID serviceId;

    /** Null = unlimited across every customer. */
    @Column(name = "max_redemptions")
    private Integer maxRedemptions;

    @Column(name = "redemptions_count", nullable = false)
    private int redemptionsCount;

    @Column(name = "starts_at")
    private Instant startsAt;

    @Column(name = "ends_at")
    private Instant endsAt;

    @Column(nullable = false)
    private boolean active;

    @Column
    private String terms;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    private long version;

    protected LoyaltyReward() {
    }

    LoyaltyReward(UUID id, UUID providerId, String name, String description, LoyaltyRewardType type, int pointsCost,
            BigDecimal discountAmount, String discountCurrency, BigDecimal discountPercentage, UUID serviceId,
            Integer maxRedemptions, Instant startsAt, Instant endsAt, String terms, Instant now) {
        this.id = id;
        this.providerId = providerId;
        this.active = true;
        this.redemptionsCount = 0;
        this.createdAt = now;
        this.updatedAt = now;
        applyEdit(name, description, type, pointsCost, discountAmount, discountCurrency, discountPercentage,
                serviceId, maxRedemptions, startsAt, endsAt, terms, now);
    }

    void applyEdit(String name, String description, LoyaltyRewardType type, int pointsCost,
            BigDecimal discountAmount, String discountCurrency, BigDecimal discountPercentage, UUID serviceId,
            Integer maxRedemptions, Instant startsAt, Instant endsAt, String terms, Instant now) {
        this.name = name;
        this.description = description;
        this.type = type;
        this.pointsCost = pointsCost;
        this.discountAmount = discountAmount;
        this.discountCurrency = discountCurrency;
        this.discountPercentage = discountPercentage;
        this.serviceId = serviceId;
        this.maxRedemptions = maxRedemptions;
        this.startsAt = startsAt;
        this.endsAt = endsAt;
        this.terms = terms;
        this.updatedAt = now;
    }

    void setActive(boolean active, Instant now) {
        this.active = active;
        this.updatedAt = now;
    }

    void incrementRedemptions() {
        this.redemptionsCount += 1;
    }

    void decrementRedemptions() {
        this.redemptionsCount = Math.max(0, this.redemptionsCount - 1);
    }

    /** Whether this reward can be redeemed right now, ignoring the customer's own points balance. */
    boolean isRedeemableAt(Instant now) {
        if (!active) {
            return false;
        }
        if (startsAt != null && now.isBefore(startsAt)) {
            return false;
        }
        if (endsAt != null && now.isAfter(endsAt)) {
            return false;
        }
        return maxRedemptions == null || redemptionsCount < maxRedemptions;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public LoyaltyRewardType getType() {
        return type;
    }

    public int getPointsCost() {
        return pointsCost;
    }

    public BigDecimal getDiscountAmount() {
        return discountAmount;
    }

    public String getDiscountCurrency() {
        return discountCurrency;
    }

    public BigDecimal getDiscountPercentage() {
        return discountPercentage;
    }

    public UUID getServiceId() {
        return serviceId;
    }

    public Integer getMaxRedemptions() {
        return maxRedemptions;
    }

    public int getRedemptionsCount() {
        return redemptionsCount;
    }

    public Instant getStartsAt() {
        return startsAt;
    }

    public Instant getEndsAt() {
        return endsAt;
    }

    public boolean isActive() {
        return active;
    }

    public String getTerms() {
        return terms;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
