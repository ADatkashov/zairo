package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

/**
 * One earning event's own FIFO expiry bucket -- see this module's own
 * package-info ("Immutable ledger, mutable cache"). Created alongside
 * every points-adding {@link LoyaltyTransaction} (EARNED, BONUS, REFUND,
 * a positive ADJUSTMENT/REVERSAL); {@link #pointsRemaining} is decremented
 * as those exact points are spent (oldest lot first) or expire, whichever
 * happens first -- never both.
 */
@Entity
@Table(name = "loyalty_earn_lot")
public class LoyaltyEarnLot {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "transaction_id", nullable = false, unique = true)
    private UUID transactionId;

    @Column(name = "points_earned", nullable = false)
    private int pointsEarned;

    @Column(name = "points_remaining", nullable = false)
    private int pointsRemaining;

    @Column(name = "earned_at", nullable = false)
    private Instant earnedAt;

    /** Null = these points never expire (program had expiration disabled when they were earned). */
    @Column(name = "expires_at")
    private Instant expiresAt;

    @Version
    private long version;

    protected LoyaltyEarnLot() {
    }

    LoyaltyEarnLot(UUID id, UUID providerId, UUID userId, UUID transactionId, int pointsEarned, Instant earnedAt,
            Instant expiresAt) {
        this.id = id;
        this.providerId = providerId;
        this.userId = userId;
        this.transactionId = transactionId;
        this.pointsEarned = pointsEarned;
        this.pointsRemaining = pointsEarned;
        this.earnedAt = earnedAt;
        this.expiresAt = expiresAt;
    }

    /** Consumes up to {@code amount} from this lot, returning how much was actually taken (may be less than asked). */
    int consume(int amount) {
        int taken = Math.min(amount, pointsRemaining);
        pointsRemaining -= taken;
        return taken;
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

    public UUID getTransactionId() {
        return transactionId;
    }

    public int getPointsEarned() {
        return pointsEarned;
    }

    public int getPointsRemaining() {
        return pointsRemaining;
    }

    public Instant getEarnedAt() {
        return earnedAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }
}
