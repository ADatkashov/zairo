package com.zairo.factory.subscriptions;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

/**
 * One row per owner ({@code ownerUserId} unique) — every owner implicitly
 * has a subscription, created lazily (FREE, ACTIVE) the first time one is
 * needed (see SubscriptionService.getOrCreate), rather than treating "no
 * row" as a special-cased default. Mirrors Provider always starting PENDING:
 * one obvious default state, no null-branching elsewhere in the codebase.
 */
@Entity
@Table(name = "subscription")
public class Subscription {

    @Id
    private UUID id;

    @Column(name = "owner_user_id", nullable = false, unique = true)
    private UUID ownerUserId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SubscriptionPlan plan;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SubscriptionStatus status;

    @Column(name = "current_period_start", nullable = false)
    private Instant currentPeriodStart;

    @Column(name = "current_period_end", nullable = false)
    private Instant currentPeriodEnd;

    @Column(name = "grace_period_ends_at")
    private Instant gracePeriodEndsAt;

    /**
     * Set by {@link #requestDowngradeAtPeriodEnd()} — PRO benefits and
     * billing continue until {@code currentPeriodEnd} (no proration, no
     * refund of the period already paid for); the renewal job downgrades to
     * FREE instead of charging once that boundary is reached. Never true for
     * a FREE subscription (there's nothing to downgrade from).
     */
    @Column(name = "cancel_at_period_end", nullable = false)
    private boolean cancelAtPeriodEnd;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Subscription() {
    }

    public Subscription(UUID id, UUID ownerUserId, Instant now) {
        this.id = id;
        this.ownerUserId = ownerUserId;
        this.plan = SubscriptionPlan.FREE;
        this.status = SubscriptionStatus.ACTIVE;
        this.currentPeriodStart = now;
        this.currentPeriodEnd = now.plus(30, ChronoUnit.DAYS);
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getOwnerUserId() {
        return ownerUserId;
    }

    public SubscriptionPlan getPlan() {
        return plan;
    }

    public SubscriptionStatus getStatus() {
        return status;
    }

    public Instant getCurrentPeriodStart() {
        return currentPeriodStart;
    }

    public Instant getCurrentPeriodEnd() {
        return currentPeriodEnd;
    }

    public Instant getGracePeriodEndsAt() {
        return gracePeriodEndsAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public boolean isCancelAtPeriodEnd() {
        return cancelAtPeriodEnd;
    }

    /** Starts a fresh full-price period immediately — no proration for the switch from FREE. */
    void markUpgradedToPro(Instant now) {
        this.plan = SubscriptionPlan.PRO;
        this.status = SubscriptionStatus.ACTIVE;
        this.currentPeriodStart = now;
        this.currentPeriodEnd = now.plus(30, ChronoUnit.DAYS);
        this.cancelAtPeriodEnd = false;
        this.gracePeriodEndsAt = null;
        this.updatedAt = now;
    }

    /** No-op if already FREE or already flagged — PRO access continues until the current period's end. */
    void requestDowngradeAtPeriodEnd(Instant now) {
        if (plan == SubscriptionPlan.FREE) {
            return;
        }
        this.cancelAtPeriodEnd = true;
        this.updatedAt = now;
    }

    /** Undoes {@link #requestDowngradeAtPeriodEnd} — plan/status/period are untouched, only the flag clears. */
    void clearDowngradeRequest(Instant now) {
        this.cancelAtPeriodEnd = false;
        this.updatedAt = now;
    }

    void markRenewed(Instant now) {
        this.status = SubscriptionStatus.ACTIVE;
        this.currentPeriodStart = now;
        this.currentPeriodEnd = now.plus(30, ChronoUnit.DAYS);
        this.gracePeriodEndsAt = null;
        this.updatedAt = now;
    }

    /** First failed renewal charge only — a retry within an already-open grace period doesn't reset the window. */
    void markPastDue(Instant now, Instant gracePeriodEndsAt) {
        this.status = SubscriptionStatus.PAST_DUE;
        if (this.gracePeriodEndsAt == null) {
            this.gracePeriodEndsAt = gracePeriodEndsAt;
        }
        this.updatedAt = now;
    }

    /** Grace period expired without a successful charge, or a self-service downgrade reached its period end. */
    void downgradeToFree(Instant now) {
        this.plan = SubscriptionPlan.FREE;
        this.status = SubscriptionStatus.ACTIVE;
        this.currentPeriodStart = now;
        this.currentPeriodEnd = now.plus(30, ChronoUnit.DAYS);
        this.gracePeriodEndsAt = null;
        this.cancelAtPeriodEnd = false;
        this.updatedAt = now;
    }
}
