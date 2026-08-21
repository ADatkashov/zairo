package com.zairo.factory.services;

import com.zairo.factory.money.Money;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
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

    /**
     * Was two independent columns (price + currency); now one Money value
     * type, kept on the same column names via @AttributeOverrides so this
     * is a representation change only — see V17__money_value_type.sql.
     */
    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "price", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money price;

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
        this.price = new Money(price, currency);
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

    /** Kept as a plain BigDecimal getter — every existing caller (ServiceResponse, etc.) already expects this shape. */
    public BigDecimal getPrice() {
        return price.amount();
    }

    public String getCurrency() {
        return price.currencyCode();
    }

    public boolean isActive() {
        return active;
    }

    void update(String title, int durationMinutes, BigDecimal price, String currency) {
        this.title = title;
        this.durationMinutes = durationMinutes;
        this.price = new Money(price, currency);
    }

    /** Soft-delete: existing bookings still reference this service by id, so the row must stay. */
    void deactivate() {
        this.active = false;
    }

    void reactivate() {
        this.active = true;
    }
}
