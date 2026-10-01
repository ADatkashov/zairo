package com.zairo.factory.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * One issued OTP code for one phone-verification attempt. Every request
 * creates a new row (see V63 migration's doc comment) — the current code
 * for a phone number is always the most recent, unconsumed, unexpired row
 * for it (see PhoneOtpRepository.findTopByPhoneOrderByCreatedAtDesc).
 */
@Entity
@Table(name = "phone_otp")
public class PhoneOtp {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String phone;

    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    @Column(nullable = false)
    private int attempts;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "consumed_at")
    private Instant consumedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected PhoneOtp() {
    }

    PhoneOtp(UUID id, String phone, String codeHash, Instant expiresAt, Instant createdAt) {
        this.id = id;
        this.phone = phone;
        this.codeHash = codeHash;
        this.attempts = 0;
        this.expiresAt = expiresAt;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public String getPhone() {
        return phone;
    }

    public String getCodeHash() {
        return codeHash;
    }

    public int getAttempts() {
        return attempts;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public Instant getConsumedAt() {
        return consumedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public boolean isExpired(Instant now) {
        return now.isAfter(expiresAt);
    }

    public boolean isConsumed() {
        return consumedAt != null;
    }

    /**
     * Package-private, used only by PhoneOtpServiceTest's in-memory fake
     * repository — the real repository never mutates a loaded entity this
     * way, it applies {@link PhoneOtpRepository#consume}/{@code
     * incrementAttempts} as atomic bulk UPDATEs instead (see that
     * interface's doc comment on why: race-safety needs the database's
     * row-level locking, which mutating a Java object in memory can't
     * provide).
     */
    void consume(Instant now) {
        this.consumedAt = now;
    }

    void incrementAttempts() {
        this.attempts++;
    }
}
