package com.zairo.factory.workforce;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** What one worker charges for one service, when it differs from the service's own price. */
@Entity
@Table(name = "worker_service_price")
public class WorkerServicePrice {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false, updatable = false)
    private UUID providerId;

    @Column(name = "worker_id", nullable = false, updatable = false)
    private UUID workerId;

    @Column(name = "service_id", nullable = false, updatable = false)
    private UUID serviceId;

    @Column(name = "price", nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected WorkerServicePrice() {
    }

    public WorkerServicePrice(UUID providerId, UUID workerId, UUID serviceId, BigDecimal price, Instant now) {
        this.id = UUID.randomUUID();
        this.providerId = providerId;
        this.workerId = workerId;
        this.serviceId = serviceId;
        this.price = price;
        this.updatedAt = now;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public UUID getWorkerId() {
        return workerId;
    }

    public UUID getServiceId() {
        return serviceId;
    }

    public BigDecimal getPrice() {
        return price;
    }

    void setPrice(BigDecimal price, Instant now) {
        this.price = price;
        this.updatedAt = now;
    }
}
