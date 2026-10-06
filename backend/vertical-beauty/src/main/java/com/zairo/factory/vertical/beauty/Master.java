package com.zairo.factory.vertical.beauty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * A stylist/technician who works at a Core {@code Provider} (salon).
 * References the provider by id only — see build.gradle.kts for the one
 * exception to that rule (booking creation via Core's BookingService).
 */
@Entity
@Table(name = "beauty_master")
public class Master {

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

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Master() {
    }

    public Master(UUID id, UUID providerId, String displayName, String bio, String photoUrl, boolean active,
            Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.displayName = displayName;
        this.bio = bio;
        this.photoUrl = photoUrl;
        this.active = active;
        this.createdAt = createdAt;
    }

    /** Sets the registered user this master was picked from; null for hand-entered masters. */
    public Master withUserId(UUID userId) {
        this.userId = userId;
        return this;
    }

    public UUID getUserId() {
        return userId;
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

    void updatePhoto(String photoUrl) {
        this.photoUrl = photoUrl;
    }

    /** Soft-delete: existing bookings/portfolio items still reference this master by id, so the row must stay. */
    void deactivate() {
        this.active = false;
    }

    void reactivate() {
        this.active = true;
    }
}
