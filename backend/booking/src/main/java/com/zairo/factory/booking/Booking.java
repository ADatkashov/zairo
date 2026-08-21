package com.zairo.factory.booking;

import com.zairo.factory.money.Money;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * References {@code userId}/{@code serviceId} by id only — booking never
 * imports the users/services module's entity classes, matching the
 * bounded-context boundary in docs/erd/core-domain.md.
 */
@Entity
@Table(name = "booking")
public class Booking {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    @Column(name = "availability_slot_id", nullable = false)
    private UUID availabilitySlotId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BookingStatus status;

    /**
     * Was a bare BigDecimal with no currency of its own (implicitly "the
     * platform default", never actually stored) — now a real Money, backed
     * by a new currency column backfilled from each booking's own service
     * at migration time. See V17__money_value_type.sql and
     * BookingService.createBooking (currency comes from the same platform
     * default config Payment used to configure independently).
     */
    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "total_price", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money totalPrice;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Booking() {
    }

    public Booking(UUID id, UUID userId, UUID serviceId, UUID availabilitySlotId, BookingStatus status,
            BigDecimal totalPrice, String currency, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.serviceId = serviceId;
        this.availabilitySlotId = availabilitySlotId;
        this.status = status;
        this.totalPrice = new Money(totalPrice, currency);
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getServiceId() {
        return serviceId;
    }

    public UUID getAvailabilitySlotId() {
        return availabilitySlotId;
    }

    public BookingStatus getStatus() {
        return status;
    }

    public BigDecimal getTotalPrice() {
        return totalPrice.amount();
    }

    public String getCurrency() {
        return totalPrice.currencyCode();
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    void markCompleted() {
        this.status = BookingStatus.COMPLETED;
    }

    void markCancelled() {
        this.status = BookingStatus.CANCELLED;
    }
}
