package com.zairo.factory.providers;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * {@code vertical} is stored and returned as-is; this module never parses or
 * branches on its value — see docs/erd/core-domain.md.
 */
@Entity
@Table(name = "provider")
public class Provider {

    @Id
    private UUID id;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String vertical;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ProviderStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * Nullable — set directly by the caller (curl/seed data/future business
     * onboarding UI), no geocoding-from-address step. A real address ->
     * lat/lng lookup would need an external geocoding service; deferred
     * along with everything else map-related that needs a real provider
     * account (see search module's distance ranking and
     * apps/user_app/lib/features/maps/).
     */
    @Column
    private Double latitude;

    @Column
    private Double longitude;

    protected Provider() {
    }

    public Provider(UUID id, UUID ownerUserId, String name, String vertical, ProviderStatus status,
            Instant createdAt) {
        this(id, ownerUserId, name, vertical, status, createdAt, null, null);
    }

    public Provider(UUID id, UUID ownerUserId, String name, String vertical, ProviderStatus status,
            Instant createdAt, Double latitude, Double longitude) {
        this.id = id;
        this.ownerUserId = ownerUserId;
        this.name = name;
        this.vertical = vertical;
        this.status = status;
        this.createdAt = createdAt;
        this.latitude = latitude;
        this.longitude = longitude;
    }

    public UUID getId() {
        return id;
    }

    public UUID getOwnerUserId() {
        return ownerUserId;
    }

    public String getName() {
        return name;
    }

    public String getVertical() {
        return vertical;
    }

    public ProviderStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Double getLatitude() {
        return latitude;
    }

    public Double getLongitude() {
        return longitude;
    }
}
