package com.zairo.factory.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.UUID;

/**
 * A single verified external identity (a Google account, a Facebook
 * account, or a phone number) linked to one {@code app_user}. {@code
 * providerSubject} is always the provider's own durable identifier — the
 * Google "sub" claim, the Facebook Graph "id" field, or the E.164-normalized
 * phone number for {@link IdentityProvider#PHONE} — never anything the
 * client sent that hasn't itself been cryptographically or OTP-verified.
 *
 * <p>Deliberately its own table rather than nullable columns on {@code
 * User} (see V63 migration): a user can have more than one of these, and
 * the {@code (provider, provider_subject)} unique constraint is what makes
 * "this Google account already belongs to someone else" a database
 * guarantee, not just an application-level check racing against a
 * concurrent request.
 */
@Entity
@Table(name = "user_identity",
        uniqueConstraints = @UniqueConstraint(name = "uq_user_identity_provider_subject",
                columnNames = {"provider", "provider_subject"}))
public class UserIdentity {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private IdentityProvider provider;

    @Column(name = "provider_subject", nullable = false)
    private String providerSubject;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected UserIdentity() {
    }

    UserIdentity(UUID id, UUID userId, IdentityProvider provider, String providerSubject, Instant now) {
        this.id = id;
        this.userId = userId;
        this.provider = provider;
        this.providerSubject = providerSubject;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public IdentityProvider getProvider() {
        return provider;
    }

    public String getProviderSubject() {
        return providerSubject;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
