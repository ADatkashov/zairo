package com.zairo.factory.vertical.auto;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Records which {@link Mechanic} and {@link Vehicle} a Core {@code Booking}
 * was made with. Kept as a separate link table rather than columns on
 * Core's {@code booking} table — same reasoning as vertical-beauty's
 * {@code MasterBooking}.
 */
@Entity
@Table(name = "auto_booking")
public class AutoBooking {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false, unique = true)
    private UUID bookingId;

    @Column(name = "mechanic_id", nullable = false)
    private UUID mechanicId;

    @Column(name = "vehicle_id", nullable = false)
    private UUID vehicleId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected AutoBooking() {
    }

    public AutoBooking(UUID id, UUID bookingId, UUID mechanicId, UUID vehicleId, Instant createdAt) {
        this.id = id;
        this.bookingId = bookingId;
        this.mechanicId = mechanicId;
        this.vehicleId = vehicleId;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getMechanicId() {
        return mechanicId;
    }

    public UUID getVehicleId() {
        return vehicleId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
