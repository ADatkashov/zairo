package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

/**
 * One customer's balance with one business -- unique on ({@code
 * providerId}, {@code userId}). {@link #pointsBalance} is a cache kept in
 * lock-step with {@link LoyaltyTransaction} inserts (see
 * LoyaltyLedgerService); it is never the sole record of anything, only a
 * cheap read of a total the ledger could always reproduce.
 */
@Entity
@Table(name = "loyalty_account")
public class LoyaltyAccount {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "points_balance", nullable = false)
    private int pointsBalance;

    @Column(name = "lifetime_earned", nullable = false)
    private int lifetimeEarned;

    @Column(name = "lifetime_redeemed", nullable = false)
    private int lifetimeRedeemed;

    @Column(name = "lifetime_expired", nullable = false)
    private int lifetimeExpired;

    /** Completed-booking count with this business, mirrored here so milestone/repeat-visit checks don't re-query booking. */
    @Column(name = "completed_visits", nullable = false)
    private int completedVisits;

    @Column(name = "last_activity_at")
    private Instant lastActivityAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Version
    private long version;

    protected LoyaltyAccount() {
    }

    LoyaltyAccount(UUID id, UUID providerId, UUID userId, Instant now) {
        this.id = id;
        this.providerId = providerId;
        this.userId = userId;
        this.pointsBalance = 0;
        this.lifetimeEarned = 0;
        this.lifetimeRedeemed = 0;
        this.lifetimeExpired = 0;
        this.completedVisits = 0;
        this.createdAt = now;
    }

    void credit(int points, Instant now) {
        this.pointsBalance += points;
        this.lifetimeEarned += points;
        this.lastActivityAt = now;
    }

    /** {@code type} distinguishes what the debit counts against for lifetime reporting -- redeemed vs. expired. */
    void debit(int points, LoyaltyTransactionType type, Instant now) {
        if (points > this.pointsBalance) {
            throw new IllegalStateException("Cannot debit " + points + " points from account " + id
                    + " with only " + this.pointsBalance + " available");
        }
        this.pointsBalance -= points;
        if (type == LoyaltyTransactionType.EXPIRED) {
            this.lifetimeExpired += points;
        } else {
            this.lifetimeRedeemed += points;
        }
        this.lastActivityAt = now;
    }

    /**
     * Overwrites (never increments) with a freshly-counted total -- the
     * caller always recomputes this from {@code Booking} itself (see
     * LoyaltyEarningListener), so re-applying the same booking-completed
     * event twice lands on the same number instead of double-counting.
     */
    void syncCompletedVisits(int completedVisits, Instant now) {
        this.completedVisits = completedVisits;
        this.lastActivityAt = now;
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

    public int getPointsBalance() {
        return pointsBalance;
    }

    public int getLifetimeEarned() {
        return lifetimeEarned;
    }

    public int getLifetimeRedeemed() {
        return lifetimeRedeemed;
    }

    public int getLifetimeExpired() {
        return lifetimeExpired;
    }

    public int getCompletedVisits() {
        return completedVisits;
    }

    public Instant getLastActivityAt() {
        return lastActivityAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
