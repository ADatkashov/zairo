package com.zairo.factory.workforce;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Rules the business owner controls about its workers. A business with no row uses the defaults. */
@Entity
@Table(name = "provider_workforce_settings")
public class ProviderWorkforceSettings {

    @Id
    @Column(name = "provider_id")
    private UUID providerId;

    /** Whether a customer may pick a specific person (otherwise only "any master"). Default: yes. */
    @Column(name = "allow_worker_choice", nullable = false)
    private boolean allowWorkerChoice = true;

    /** Whether the owner sets a different price per worker. Default: no. */
    @Column(name = "worker_pricing_enabled", nullable = false)
    private boolean workerPricingEnabled;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected ProviderWorkforceSettings() {
    }

    public ProviderWorkforceSettings(UUID providerId, boolean allowWorkerChoice, boolean workerPricingEnabled,
            Instant now) {
        this.providerId = providerId;
        this.allowWorkerChoice = allowWorkerChoice;
        this.workerPricingEnabled = workerPricingEnabled;
        this.updatedAt = now;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public boolean isAllowWorkerChoice() {
        return allowWorkerChoice;
    }

    public boolean isWorkerPricingEnabled() {
        return workerPricingEnabled;
    }

    void update(boolean allowWorkerChoice, boolean workerPricingEnabled, Instant now) {
        this.allowWorkerChoice = allowWorkerChoice;
        this.workerPricingEnabled = workerPricingEnabled;
        this.updatedAt = now;
    }
}
