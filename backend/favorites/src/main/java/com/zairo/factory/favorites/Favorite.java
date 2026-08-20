package com.zairo.factory.favorites;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "favorite")
public class Favorite {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Favorite() {
    }

    public Favorite(UUID id, UUID userId, UUID providerId, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.providerId = providerId;
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

    public Instant getCreatedAt() {
        return createdAt;
    }
}
