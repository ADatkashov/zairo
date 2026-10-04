package com.zairo.factory.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** A started-but-not-finished WebAuthn registration or login: the issued options, challenge included. */
@Entity
@Table(name = "webauthn_ceremony")
public class WebauthnCeremony {

    enum Kind {
        REGISTER,
        LOGIN
    }

    @Id
    private UUID id;

    @jakarta.persistence.Enumerated(jakarta.persistence.EnumType.STRING)
    @Column(nullable = false)
    private Kind kind;

    /** The user who started a REGISTER ceremony; null for LOGIN (discoverable credentials — the person isn't known yet). */
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "request_json", nullable = false)
    private String requestJson;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected WebauthnCeremony() {
    }

    WebauthnCeremony(UUID id, Kind kind, UUID userId, String requestJson, Instant expiresAt, Instant createdAt) {
        this.id = id;
        this.kind = kind;
        this.userId = userId;
        this.requestJson = requestJson;
        this.expiresAt = expiresAt;
        this.createdAt = createdAt;
    }

    UUID getId() {
        return id;
    }

    Kind getKind() {
        return kind;
    }

    UUID getUserId() {
        return userId;
    }

    String getRequestJson() {
        return requestJson;
    }

    boolean isExpired(Instant now) {
        return now.isAfter(expiresAt);
    }
}
