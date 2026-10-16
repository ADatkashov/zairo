package com.zairo.factory.waitlist;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * One customer waiting for one business. {@code windowStart}/{@code windowEnd} (both nullable) narrow it to the times
 * the customer wants — a day they picked, say; null means "any time". The window is a plain instant range chosen by
 * the client, so the server never has to guess a business's time zone.
 */
@Entity
@Table(name = "waitlist_entry")
public class WaitlistEntry {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "window_start")
    private Instant windowStart;

    @Column(name = "window_end")
    private Instant windowEnd;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected WaitlistEntry() {
    }

    public WaitlistEntry(UUID id, UUID userId, UUID providerId, Instant windowStart, Instant windowEnd,
            Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.providerId = providerId;
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public Instant getWindowStart() {
        return windowStart;
    }

    public Instant getWindowEnd() {
        return windowEnd;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    /** Joining again just changes the wanted window. */
    void changeWindow(Instant windowStart, Instant windowEnd) {
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
    }
}
