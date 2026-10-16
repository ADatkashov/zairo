package com.zairo.factory.workforce;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** A customer's "my master": one person on the customer's shortlist. */
@Entity
@Table(name = "favorite_worker")
public class FavoriteWorker {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "worker_id", nullable = false, updatable = false)
    private UUID workerId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected FavoriteWorker() {
    }

    public FavoriteWorker(UUID id, UUID userId, UUID workerId, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.workerId = workerId;
        this.createdAt = createdAt;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getWorkerId() {
        return workerId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
