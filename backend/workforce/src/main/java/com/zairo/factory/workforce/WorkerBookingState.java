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
 * What a worker (and the owner) have said about one booking, kept in one place for all four kinds instead of
 * columns on four link tables: whether the worker accepted it, whether they told the owner they can't attend, and
 * whether the customer asked for this exact person or "any master".
 */
@Entity
@Table(name = "worker_booking_state")
public class WorkerBookingState {

    public enum Preference {
        /** The customer chose this person. */
        SPECIFIC,
        /** The customer didn't mind who — the business may swap the person freely. */
        ANY
    }

    @Id
    @Column(name = "booking_id")
    private UUID bookingId;

    @Column(name = "worker_id", nullable = false)
    private UUID workerId;

    @Column(name = "confirmed_at")
    private Instant confirmedAt;

    @Column(name = "declined_at")
    private Instant declinedAt;

    @Column(name = "decline_reason", length = 500)
    private String declineReason;

    @Column(name = "unaccepted_warned_at")
    private Instant unacceptedWarnedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Preference preference = Preference.SPECIFIC;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected WorkerBookingState() {
    }

    public WorkerBookingState(UUID bookingId, UUID workerId, Preference preference, Instant createdAt) {
        this.bookingId = bookingId;
        this.workerId = workerId;
        this.preference = preference;
        this.createdAt = createdAt;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getWorkerId() {
        return workerId;
    }

    public Instant getConfirmedAt() {
        return confirmedAt;
    }

    public Instant getDeclinedAt() {
        return declinedAt;
    }

    public String getDeclineReason() {
        return declineReason;
    }

    public Instant getUnacceptedWarnedAt() {
        return unacceptedWarnedAt;
    }

    void markUnacceptedWarned(Instant at) {
        this.unacceptedWarnedAt = at;
    }

    public Preference getPreference() {
        return preference;
    }

    /** Idempotent: the first acceptance stands. */
    void confirm(Instant at) {
        if (confirmedAt == null) {
            confirmedAt = at;
        }
    }

    /** Idempotent: the first request (and its reason) stands. */
    void requestDecline(Instant at, String reason) {
        if (declinedAt == null) {
            declinedAt = at;
            declineReason = reason;
        }
    }

    /** The booking moved to another worker: the previous person's accept/decline no longer applies. */
    void reassignTo(UUID newWorkerId) {
        this.workerId = newWorkerId;
        this.confirmedAt = null;
        this.declinedAt = null;
        this.declineReason = null;
        this.unacceptedWarnedAt = null;
    }
}
