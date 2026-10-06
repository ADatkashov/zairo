package com.zairo.factory.staff;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Records which {@link Staff} member a Core {@code Booking} was made with.
 * Kept as a separate link table rather than a column on Core's
 * {@code booking} table — Core's booking flow stays vertical/staff-agnostic;
 * only this module knows a booking "belongs to" a staff member.
 */
@Entity
@Table(name = "staff_booking")
public class StaffBooking {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false, unique = true)
    private UUID bookingId;

    @Column(name = "staff_id", nullable = false)
    private UUID staffId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected StaffBooking() {
    }

    public StaffBooking(UUID id, UUID bookingId, UUID staffId, Instant createdAt) {
        this.id = id;
        this.bookingId = bookingId;
        this.staffId = staffId;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getStaffId() {
        return staffId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
