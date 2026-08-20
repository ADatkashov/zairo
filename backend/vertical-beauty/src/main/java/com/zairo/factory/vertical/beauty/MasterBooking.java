package com.zairo.factory.vertical.beauty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Records which {@link Master} a Core {@code Booking} was made with. Kept
 * as a separate link table rather than a column on Core's {@code booking}
 * table — Core's booking flow stays vertical-agnostic; only this module
 * knows a booking "belongs to" a master.
 */
@Entity
@Table(name = "beauty_master_booking")
public class MasterBooking {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false, unique = true)
    private UUID bookingId;

    @Column(name = "master_id", nullable = false)
    private UUID masterId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected MasterBooking() {
    }

    public MasterBooking(UUID id, UUID bookingId, UUID masterId, Instant createdAt) {
        this.id = id;
        this.bookingId = bookingId;
        this.masterId = masterId;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getMasterId() {
        return masterId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
