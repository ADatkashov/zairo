package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/**
 * One configurable "reach N completed visits, get M points" rule owned by
 * a {@link LoyaltyProgram} -- deliberately not hardcoded tiers (see this
 * module's own package-info and Phase 13 of the feature brief): a business
 * defines as many or as few of these as it wants. Award-once-per-account
 * is enforced by a partial unique index on {@code loyalty_transaction}
 * (referenceType=MILESTONE, referenceId=this rule's id), not here.
 */
@Entity
@Table(name = "loyalty_milestone_rule")
public class LoyaltyMilestoneRule {

    @Id
    private UUID id;

    @Column(name = "program_id", nullable = false)
    private UUID programId;

    @Column(name = "visits_required", nullable = false)
    private int visitsRequired;

    @Column(name = "points_awarded", nullable = false)
    private int pointsAwarded;

    @Column
    private String label;

    protected LoyaltyMilestoneRule() {
    }

    public LoyaltyMilestoneRule(UUID id, UUID programId, int visitsRequired, int pointsAwarded, String label) {
        this.id = id;
        this.programId = programId;
        this.visitsRequired = visitsRequired;
        this.pointsAwarded = pointsAwarded;
        this.label = label;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProgramId() {
        return programId;
    }

    public int getVisitsRequired() {
        return visitsRequired;
    }

    public int getPointsAwarded() {
        return pointsAwarded;
    }

    public String getLabel() {
        return label;
    }
}
