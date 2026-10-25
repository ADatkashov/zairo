package com.zairo.factory.subscriptions;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;

/** A paid plan's monthly price as set by the platform (V103); one row per plan. */
@Entity
@Table(name = "subscription_price")
public class SubscriptionPriceRow {

    @Id
    @Enumerated(EnumType.STRING)
    private SubscriptionPlan plan;

    @Column(name = "monthly_price", nullable = false)
    private BigDecimal monthlyPrice;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "updated_by")
    private String updatedBy;

    protected SubscriptionPriceRow() {
    }

    SubscriptionPriceRow(SubscriptionPlan plan, BigDecimal monthlyPrice, String currency, Instant updatedAt,
            String updatedBy) {
        this.plan = plan;
        this.monthlyPrice = monthlyPrice;
        this.currency = currency;
        this.updatedAt = updatedAt;
        this.updatedBy = updatedBy;
    }

    public SubscriptionPlan getPlan() {
        return plan;
    }

    public BigDecimal getMonthlyPrice() {
        return monthlyPrice;
    }

    public String getCurrency() {
        return currency;
    }

    void change(BigDecimal monthlyPrice, String currency, Instant updatedAt, String updatedBy) {
        this.monthlyPrice = monthlyPrice;
        this.currency = currency;
        this.updatedAt = updatedAt;
        this.updatedBy = updatedBy;
    }
}
