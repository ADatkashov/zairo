package com.zairo.factory.booking;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

/**
 * {@code @Version} gives optimistic locking on the status transition
 * OPEN -> BOOKED, so two concurrent booking requests for the same slot can't
 * both succeed — the loser gets an OptimisticLockingFailureException, which
 * {@link BookingService} turns into a 409 conflict.
 */
@Entity
@Table(name = "availability_slot")
public class AvailabilitySlot {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "starts_at", nullable = false)
    private Instant startsAt;

    @Column(name = "ends_at", nullable = false)
    private Instant endsAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AvailabilityStatus status;

    @Version
    private long version;

    protected AvailabilitySlot() {
    }

    public AvailabilitySlot(UUID id, UUID providerId, Instant startsAt, Instant endsAt,
            AvailabilityStatus status) {
        this.id = id;
        this.providerId = providerId;
        this.startsAt = startsAt;
        this.endsAt = endsAt;
        this.status = status;
    }

    public UUID getId() {
        return id;
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

    public AvailabilityStatus getStatus() {
        return status;
    }

    void markBooked() {
        this.status = AvailabilityStatus.BOOKED;
    }
}
