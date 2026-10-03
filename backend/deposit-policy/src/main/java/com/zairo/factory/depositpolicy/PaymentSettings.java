package com.zairo.factory.depositpolicy;

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
 * Per-provider payment configuration.
 * One row per provider, created on first access with default settings
 * (NO_PAYMENT required, no deposit).
 *
 * When depositType is DEPOSIT:
 * - depositValueType determines if depositValue is a percentage (0-100) or fixed amount
 * - depositValue is the percentage (0-100) or the fixed amount in booking currency
 *
 * Settings apply to new bookings created after the settings are changed.
 * Existing bookings retain their payment settings captured at booking creation time.
 */
@Entity
@Table(name = "payment_settings")
public class PaymentSettings {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false, unique = true)
    private UUID providerId;

    @Enumerated(EnumType.STRING)
    @Column(name = "deposit_type", nullable = false)
    private DepositType depositType;

    /** Only relevant when depositType == DEPOSIT */
    @Enumerated(EnumType.STRING)
    @Column(name = "deposit_value_type")
    private DepositValueType depositValueType;

    /** Percentage (0-100) or fixed amount depending on depositValueType. Null when depositType != DEPOSIT. */
    @Column(name = "deposit_value", precision = 10, scale = 2)
    private BigDecimal depositValue;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    private long version;

    protected PaymentSettings() {
    }

    PaymentSettings(UUID id, UUID providerId, Instant now) {
        this.id = id;
        this.providerId = providerId;
        this.depositType = DepositType.NO_PAYMENT;
        this.depositValueType = null;
        this.depositValue = null;
        this.createdAt = now;
        this.updatedAt = now;
    }

    void applySettings(DepositType depositType, DepositValueType depositValueType, BigDecimal depositValue, Instant now) {
        this.depositType = depositType;
        this.depositValueType = depositValueType;
        this.depositValue = depositValue;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public DepositType getDepositType() {
        return depositType;
    }

    public DepositValueType getDepositValueType() {
        return depositValueType;
    }

    public BigDecimal getDepositValue() {
        return depositValue;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
