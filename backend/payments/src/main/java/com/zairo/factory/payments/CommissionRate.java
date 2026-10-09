package com.zairo.factory.payments;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * One configurable commission rate — the platform-wide default when
 * {@code categoryId} is null (exactly one such row, seeded at 0% by
 * V91), otherwise an override for one catalog {@code Category}. Edited only
 * through {@link CommissionRateService}; see {@link CommissionCalculator}
 * for how a rate becomes a split.
 */
@Entity
@Table(name = "commission_rate")
public class CommissionRate {

    @Id
    private UUID id;

    /** References {@code catalog.Category} by bare id; null = the platform-wide default. */
    @Column(name = "category_id")
    private UUID categoryId;

    /** Fraction of the payment amount, 0..1. */
    @Column(nullable = false)
    private BigDecimal rate;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "updated_by")
    private String updatedBy;

    protected CommissionRate() {
    }

    CommissionRate(UUID id, UUID categoryId, BigDecimal rate, Instant updatedAt, String updatedBy) {
        this.id = id;
        this.categoryId = categoryId;
        this.rate = rate;
        this.updatedAt = updatedAt;
        this.updatedBy = updatedBy;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCategoryId() {
        return categoryId;
    }

    public BigDecimal getRate() {
        return rate;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public String getUpdatedBy() {
        return updatedBy;
    }

    void changeRate(BigDecimal rate, Instant now, String updatedBy) {
        this.rate = rate;
        this.updatedAt = now;
        this.updatedBy = updatedBy;
    }
}
