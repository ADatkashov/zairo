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
 * One customer's redemption of one {@link LoyaltyReward} -- a spend
 * already deducted from their {@link LoyaltyAccount}, plus a short code
 * the business can look up at checkout. The reward's shape (name, type,
 * discount) is copied in at redemption time so a later edit to the reward
 * catalog can never retroactively change what an already-issued code is
 * worth.
 */
@Entity
@Table(name = "loyalty_redemption")
public class LoyaltyRedemption {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "reward_id", nullable = false)
    private UUID rewardId;

    @Column(name = "points_spent", nullable = false)
    private int pointsSpent;

    @Column(nullable = false, unique = true, length = 12)
    private String code;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LoyaltyRedemptionStatus status;

    @Column(name = "reward_name_snapshot", nullable = false)
    private String rewardNameSnapshot;

    @Enumerated(EnumType.STRING)
    @Column(name = "reward_type_snapshot", nullable = false)
    private LoyaltyRewardType rewardTypeSnapshot;

    @Column(name = "discount_amount_snapshot")
    private BigDecimal discountAmountSnapshot;

    @Column(name = "discount_currency_snapshot", length = 3)
    private String discountCurrencySnapshot;

    @Column(name = "discount_percentage_snapshot")
    private BigDecimal discountPercentageSnapshot;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Column(name = "applied_booking_id")
    private UUID appliedBookingId;

    @Column(name = "applied_at")
    private Instant appliedAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "cancel_reason")
    private String cancelReason;

    @Version
    private long version;

    protected LoyaltyRedemption() {
    }

    LoyaltyRedemption(UUID id, UUID providerId, UUID userId, UUID rewardId, int pointsSpent, String code,
            LoyaltyReward reward, Instant now, Instant expiresAt) {
        this.id = id;
        this.providerId = providerId;
        this.userId = userId;
        this.rewardId = rewardId;
        this.pointsSpent = pointsSpent;
        this.code = code;
        this.status = LoyaltyRedemptionStatus.ACTIVE;
        this.rewardNameSnapshot = reward.getName();
        this.rewardTypeSnapshot = reward.getType();
        this.discountAmountSnapshot = reward.getDiscountAmount();
        this.discountCurrencySnapshot = reward.getDiscountCurrency();
        this.discountPercentageSnapshot = reward.getDiscountPercentage();
        this.createdAt = now;
        this.expiresAt = expiresAt;
    }

    void markApplied(UUID bookingId, Instant now) {
        this.status = LoyaltyRedemptionStatus.APPLIED;
        this.appliedBookingId = bookingId;
        this.appliedAt = now;
    }

    void markCancelled(String reason, Instant now) {
        this.status = LoyaltyRedemptionStatus.CANCELLED;
        this.cancelReason = reason;
        this.cancelledAt = now;
    }

    void markExpired() {
        this.status = LoyaltyRedemptionStatus.EXPIRED;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getRewardId() {
        return rewardId;
    }

    public int getPointsSpent() {
        return pointsSpent;
    }

    public String getCode() {
        return code;
    }

    public LoyaltyRedemptionStatus getStatus() {
        return status;
    }

    public String getRewardNameSnapshot() {
        return rewardNameSnapshot;
    }

    public LoyaltyRewardType getRewardTypeSnapshot() {
        return rewardTypeSnapshot;
    }

    public BigDecimal getDiscountAmountSnapshot() {
        return discountAmountSnapshot;
    }

    public String getDiscountCurrencySnapshot() {
        return discountCurrencySnapshot;
    }

    public BigDecimal getDiscountPercentageSnapshot() {
        return discountPercentageSnapshot;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public UUID getAppliedBookingId() {
        return appliedBookingId;
    }

    public Instant getAppliedAt() {
        return appliedAt;
    }

    public Instant getCancelledAt() {
        return cancelledAt;
    }

    public String getCancelReason() {
        return cancelReason;
    }
}
