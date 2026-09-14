package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * One immutable row in the points ledger -- see this module's own
 * package-info. No setters, no update path anywhere in this module: once
 * inserted, a row is never changed. Correcting a mistake means inserting a
 * new REVERSAL/ADJUSTMENT row, never editing this one.
 */
@Entity
@Table(name = "loyalty_transaction")
public class LoyaltyTransaction {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LoyaltyTransactionType type;

    /** Signed -- positive for EARNED/BONUS/REFUND and a positive ADJUSTMENT/REVERSAL, negative otherwise. */
    @Column(name = "points_delta", nullable = false)
    private int pointsDelta;

    /** The account's {@code pointsBalance} immediately after this row was applied -- an audit-trail snapshot, not a live value. */
    @Column(name = "balance_after", nullable = false)
    private int balanceAfter;

    @Column(nullable = false)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(name = "reference_type")
    private LoyaltyReferenceType referenceType;

    @Column(name = "reference_id")
    private UUID referenceId;

    @Column(name = "booking_id")
    private UUID bookingId;

    @Column(name = "reward_id")
    private UUID rewardId;

    @Column(name = "redemption_id")
    private UUID redemptionId;

    /** Who performed a {@link LoyaltyTransactionType#ADJUSTMENT} -- null for every system-generated row. */
    @Column(name = "actor_user_id")
    private UUID actorUserId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** Mirrors the earn lot's own expiry for EARNED/BONUS rows, purely for a readable history without a join. */
    @Column(name = "expires_at")
    private Instant expiresAt;

    protected LoyaltyTransaction() {
    }

    private LoyaltyTransaction(UUID id, UUID providerId, UUID userId, LoyaltyTransactionType type, int pointsDelta,
            int balanceAfter, String reason, LoyaltyReferenceType referenceType, UUID referenceId, UUID bookingId,
            UUID rewardId, UUID redemptionId, UUID actorUserId, Instant createdAt, Instant expiresAt) {
        this.id = id;
        this.providerId = providerId;
        this.userId = userId;
        this.type = type;
        this.pointsDelta = pointsDelta;
        this.balanceAfter = balanceAfter;
        this.reason = reason;
        this.referenceType = referenceType;
        this.referenceId = referenceId;
        this.bookingId = bookingId;
        this.rewardId = rewardId;
        this.redemptionId = redemptionId;
        this.actorUserId = actorUserId;
        this.createdAt = createdAt;
        this.expiresAt = expiresAt;
    }

    static LoyaltyTransaction create(UUID providerId, UUID userId, LoyaltyTransactionType type, int pointsDelta,
            int balanceAfter, String reason, LoyaltyReferenceType referenceType, UUID referenceId, UUID bookingId,
            UUID rewardId, UUID redemptionId, UUID actorUserId, Instant now, Instant expiresAt) {
        return new LoyaltyTransaction(UUID.randomUUID(), providerId, userId, type, pointsDelta, balanceAfter, reason,
                referenceType, referenceId, bookingId, rewardId, redemptionId, actorUserId, now, expiresAt);
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

    public LoyaltyTransactionType getType() {
        return type;
    }

    public int getPointsDelta() {
        return pointsDelta;
    }

    public int getBalanceAfter() {
        return balanceAfter;
    }

    public String getReason() {
        return reason;
    }

    public LoyaltyReferenceType getReferenceType() {
        return referenceType;
    }

    public UUID getReferenceId() {
        return referenceId;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getRewardId() {
        return rewardId;
    }

    public UUID getRedemptionId() {
        return redemptionId;
    }

    public UUID getActorUserId() {
        return actorUserId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }
}
