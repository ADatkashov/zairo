package com.zairo.factory.vertical.cleaning;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Records which {@link Cleaner} a Core {@code Booking} was made with. Kept
 * as a separate link table rather than a column on Core's {@code booking}
 * table — Core's booking flow stays vertical-agnostic; only this module
 * knows a booking "belongs to" a cleaner.
 */
@Entity
@Table(name = "cleaning_booking")
public class CleaningBooking {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false, unique = true)
    private UUID bookingId;

    @Column(name = "cleaner_id", nullable = false)
    private UUID cleanerId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected CleaningBooking() {
    }

    public CleaningBooking(UUID id, UUID bookingId, UUID cleanerId, Instant createdAt) {
        this.id = id;
        this.bookingId = bookingId;
        this.cleanerId = cleanerId;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getCleanerId() {
        return cleanerId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
