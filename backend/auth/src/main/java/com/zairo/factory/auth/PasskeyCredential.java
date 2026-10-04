package com.zairo.factory.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** A registered passkey: the credential id and public key only — the private key never leaves the person's device. */
@Entity
@Table(name = "passkey_credential")
public class PasskeyCredential {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "credential_id", nullable = false, updatable = false)
    private byte[] credentialId;

    @Column(name = "public_key_cose", nullable = false, updatable = false)
    private byte[] publicKeyCose;

    @Column(name = "sign_count", nullable = false)
    private long signCount;

    @Column(nullable = false)
    private String name;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "last_used_at")
    private Instant lastUsedAt;

    protected PasskeyCredential() {
    }

    PasskeyCredential(UUID id, UUID userId, byte[] credentialId, byte[] publicKeyCose, long signCount, String name,
            Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.credentialId = credentialId;
        this.publicKeyCose = publicKeyCose;
        this.signCount = signCount;
        this.name = name;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public byte[] getCredentialId() {
        return credentialId;
    }

    public byte[] getPublicKeyCose() {
        return publicKeyCose;
    }

    public long getSignCount() {
        return signCount;
    }

    public String getName() {
        return name;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getLastUsedAt() {
        return lastUsedAt;
    }

    void recordUse(long newSignCount, Instant now) {
        this.signCount = newSignCount;
        this.lastUsedAt = now;
    }
}
