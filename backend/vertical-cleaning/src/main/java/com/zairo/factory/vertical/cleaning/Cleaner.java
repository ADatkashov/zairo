package com.zairo.factory.vertical.cleaning;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * A cleaner who works at a Core {@code Provider} (a cleaning company).
 * References the provider by id only — see build.gradle.kts for the one
 * exception to that rule (booking creation via Core's BookingService).
 */
@Entity
@Table(name = "cleaning_cleaner")
public class Cleaner {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "display_name", nullable = false)
    private String displayName;

    @Column
    private String bio;

    @Column(name = "photo_url")
    private String photoUrl;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Cleaner() {
    }

    public Cleaner(UUID id, UUID providerId, String displayName, String bio, String photoUrl, boolean active,
            Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.displayName = displayName;
        this.bio = bio;
        this.photoUrl = photoUrl;
        this.active = active;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getBio() {
        return bio;
    }

    public String getPhotoUrl() {
        return photoUrl;
    }

    public boolean isActive() {
        return active;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    /** Soft-delete: existing bookings still reference this cleaner by id, so the row must stay. */
    void deactivate() {
        this.active = false;
    }

    void reactivate() {
        this.active = true;
    }
}
