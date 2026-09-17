package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/**
 * One configurable "reach N lifetime points, you're in this tier" rung,
 * owned by a {@link LoyaltyProgram} -- deliberately not a hardcoded
 * Bronze/Silver/Gold ladder (Phase 13 of the feature brief). A customer's
 * current tier is never stored; it's derived on read from {@link
 * LoyaltyAccount#getLifetimeEarned()} against these thresholds (see
 * {@link LoyaltyProgramService#currentTier}) -- simple and deterministic,
 * with no incremental state of its own that could drift.
 */
@Entity
@Table(name = "loyalty_tier_rule")
public class LoyaltyTierRule {

    @Id
    private UUID id;

    @Column(name = "program_id", nullable = false)
    private UUID programId;

    @Column(nullable = false)
    private String name;

    @Column(name = "min_lifetime_points", nullable = false)
    private int minLifetimePoints;

    protected LoyaltyTierRule() {
    }

    public LoyaltyTierRule(UUID id, UUID programId, String name, int minLifetimePoints) {
        this.id = id;
        this.programId = programId;
        this.name = name;
        this.minLifetimePoints = minLifetimePoints;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProgramId() {
        return programId;
    }

    public String getName() {
        return name;
    }

    public int getMinLifetimePoints() {
        return minLifetimePoints;
    }
}
