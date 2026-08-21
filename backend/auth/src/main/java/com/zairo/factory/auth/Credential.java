package com.zairo.factory.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Deliberately separate from users.User (see docs/erd/core-domain.md) —
 * auth owns credentials/tokens, users owns profile data.
 */
@Entity
@Table(name = "credential")
public class Credential {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false, unique = true)
    private UUID userId;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Credential() {
    }

    public Credential(UUID id, UUID userId, String passwordHash, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.passwordHash = passwordHash;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    void changePasswordHash(String newPasswordHash) {
        this.passwordHash = newPasswordHash;
    }
}
