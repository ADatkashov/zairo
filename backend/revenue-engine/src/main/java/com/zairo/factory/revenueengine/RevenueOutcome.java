package com.zairo.factory.revenueengine;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * One row per {@link DecisionEngine} decision — the ledger "Revenue
 * Recovered by ZAIRO" (and its per-{@link ActionType} breakdown) is
 * computed from. Written twice: once immediately when the decision is made
 * ({@code recovered} null = pending, {@code actualRevenue} null), and once
 * more by the executing strategy once the real outcome is known — see
 * {@link RevenueAttributionService#resolve}.
 */
@Entity
@Table(name = "revenue_outcome")
public class RevenueOutcome {

    @Id
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(name = "action_type", nullable = false)
    private ActionType actionType;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    /** Meaning depends on {@code actionType}'s trigger — for SMART_FILL, the cancelled booking's id. */
    @Column(name = "trigger_ref_id", nullable = false)
    private UUID triggerRefId;

    @Column(name = "expected_value", nullable = false)
    private BigDecimal expectedValue;

    @Column(name = "actual_revenue")
    private BigDecimal actualRevenue;

    @Column(length = 3)
    private String currency;

    /** Null = pending (decided but not yet resolved). */
    @Column
    private Boolean recovered;

    @Column(name = "decided_at", nullable = false, updatable = false)
    private Instant decidedAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    protected RevenueOutcome() {
    }

    public RevenueOutcome(UUID id, ActionType actionType, UUID providerId, UUID triggerRefId,
            BigDecimal expectedValue, String currency, Instant decidedAt) {
        this.id = id;
        this.actionType = actionType;
        this.providerId = providerId;
        this.triggerRefId = triggerRefId;
        this.expectedValue = expectedValue;
        this.currency = currency;
        this.decidedAt = decidedAt;
    }

    public UUID getId() {
        return id;
    }

    public ActionType getActionType() {
        return actionType;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public UUID getTriggerRefId() {
        return triggerRefId;
    }

    public BigDecimal getExpectedValue() {
        return expectedValue;
    }

    public BigDecimal getActualRevenue() {
        return actualRevenue;
    }

    public String getCurrency() {
        return currency;
    }

    public Boolean getRecovered() {
        return recovered;
    }

    public Instant getDecidedAt() {
        return decidedAt;
    }

    public Instant getResolvedAt() {
        return resolvedAt;
    }

    void resolve(BigDecimal actualRevenue, String currency, boolean recovered, Instant resolvedAt) {
        this.actualRevenue = actualRevenue;
        if (currency != null) {
            this.currency = currency;
        }
        this.recovered = recovered;
        this.resolvedAt = resolvedAt;
    }
}
