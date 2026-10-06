package com.zairo.factory.workforce;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** A period in which a worker can't be booked: day off, sick leave, vacation, "the master isn't in today". */
@Entity
@Table(name = "worker_time_off")
public class WorkerTimeOff {

    @Id
    private UUID id;

    @Column(name = "worker_id", nullable = false)
    private UUID workerId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "starts_at", nullable = false)
    private Instant startsAt;

    @Column(name = "ends_at", nullable = false)
    private Instant endsAt;

    @Column(length = 255)
    private String reason;

    /** The user who recorded it: the owner, or the worker themselves (who may only ever reduce availability). */
    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected WorkerTimeOff() {
    }

    public WorkerTimeOff(UUID id, UUID workerId, UUID providerId, Instant startsAt, Instant endsAt, String reason,
            UUID createdBy, Instant createdAt) {
        this.id = id;
        this.workerId = workerId;
        this.providerId = providerId;
        this.startsAt = startsAt;
        this.endsAt = endsAt;
        this.reason = reason;
        this.createdBy = createdBy;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getWorkerId() {
        return workerId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public Instant getStartsAt() {
        return startsAt;
    }

    public Instant getEndsAt() {
        return endsAt;
    }

    public String getReason() {
        return reason;
    }

    public UUID getCreatedBy() {
        return createdBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public boolean overlaps(Instant from, Instant to) {
        return startsAt.isBefore(to) && endsAt.isAfter(from);
    }
}
