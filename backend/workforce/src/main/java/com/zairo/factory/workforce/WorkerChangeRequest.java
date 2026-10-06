package com.zairo.factory.workforce;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * The owner asked the customer to decide what happens to an appointment whose person can't make it: take a
 * colleague at the same time, move to another time, or cancel with a refund. Used only for customers who chose a
 * specific person — "any master" customers are re-assigned without being asked.
 */
@Entity
@Table(name = "worker_change_request")
public class WorkerChangeRequest {

    public enum Status {
        OPEN, RESOLVED
    }

    public enum Resolution {
        /** The customer picked a colleague. */
        REPLACED,
        /** The customer picked another time. */
        MOVED,
        /** The customer cancelled (and was refunded). */
        CANCELLED,
        /** The owner decided before the customer did. */
        OWNER_DECIDED
    }

    @Id
    @Column(name = "booking_id")
    private UUID bookingId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(nullable = false, length = 32)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status;

    @Enumerated(EnumType.STRING)
    @Column(length = 24)
    private Resolution resolution;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    protected WorkerChangeRequest() {
    }

    public WorkerChangeRequest(UUID bookingId, UUID providerId, String reason, Instant createdAt) {
        this.bookingId = bookingId;
        this.providerId = providerId;
        this.reason = reason;
        this.status = Status.OPEN;
        this.createdAt = createdAt;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public String getReason() {
        return reason;
    }

    public Status getStatus() {
        return status;
    }

    public Resolution getResolution() {
        return resolution;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getResolvedAt() {
        return resolvedAt;
    }

    void resolve(Resolution resolution, Instant at) {
        if (status == Status.OPEN) {
            this.status = Status.RESOLVED;
            this.resolution = resolution;
            this.resolvedAt = at;
        }
    }
}
