package com.zairo.factory.services;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.util.UUID;

/**
 * Maps to the {@code SERVICE} entity in docs/erd/core-domain.md. Named
 * {@code ServiceOffering} in Java to avoid clashing with Spring's
 * {@code @Service} stereotype annotation, which shares the simple name
 * {@code Service}.
 */
@Entity
@Table(name = "service")
public class ServiceOffering {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(nullable = false)
    private String title;

    @Column(name = "duration_minutes", nullable = false)
    private int durationMinutes;

    @Column(nullable = false)
    private BigDecimal price;

    @Column(nullable = false)
    private String currency;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    protected ServiceOffering() {
    }

    public ServiceOffering(UUID id, UUID providerId, String title, int durationMinutes, BigDecimal price,
            String currency, boolean active) {
        this.id = id;
        this.providerId = providerId;
        this.title = title;
        this.durationMinutes = durationMinutes;
        this.price = price;
        this.currency = currency;
        this.active = active;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public String getTitle() {
        return title;
    }

    public int getDurationMinutes() {
        return durationMinutes;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public String getCurrency() {
        return currency;
    }

    public boolean isActive() {
        return active;
    }
}
