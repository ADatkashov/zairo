package com.zairo.factory.users;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "app_user")
public class User {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private String email;

    private String phone;

    /**
     * True only when {@link #email} was vouched for by a provider (Google/
     * Facebook) — see V73. Never set from a typed-in registration email.
     */
    @Column(name = "email_verified", nullable = false)
    private boolean emailVerified;

    @Column(name = "display_name", nullable = false)
    private String displayName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserRole role;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "avatar_url")
    private String avatarUrl;

    @Column(name = "current_city_code")
    private String currentCityCode;

    protected User() {
    }

    public User(UUID id, String email, String phone, String displayName, UserRole role, Instant createdAt) {
        this.id = id;
        this.email = email;
        this.phone = phone;
        this.displayName = displayName;
        this.role = role;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public boolean isEmailVerified() {
        return emailVerified;
    }

    public void markEmailVerified() {
        this.emailVerified = true;
    }

    public String getPhone() {
        return phone;
    }

    public String getDisplayName() {
        return displayName;
    }

    public UserRole getRole() {
        return role;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public String getCurrentCityCode() {
        return currentCityCode;
    }

    /** Null/blank removes the avatar — see AuthDtos.UpdateAvatarRequest. */
    public void updateAvatar(String avatarUrl) {
        this.avatarUrl = avatarUrl;
    }

    /** Set user's current city for booking services in that city. */
    public void setCurrentCityCode(String currentCityCode) {
        this.currentCityCode = currentCityCode;
    }

    /**
     * Profile completion for an account created via Google/Facebook/phone
     * (see auth.IdentityService) that started without one or both of these
     * — e.g. a phone-only signup has no email, a Facebook signup that
     * didn't grant the email permission has no email either. Either
     * argument may be null/blank to leave that field unchanged; email
     * uniqueness is enforced by the caller (auth.AuthService) before this
     * is called, same division of responsibility as everywhere else in
     * this class.
     */
    public void updateProfile(String displayName, String email) {
        if (displayName != null && !displayName.isBlank()) {
            this.displayName = displayName;
        }
        if (email != null && !email.isBlank()) {
            this.email = email;
        }
    }

    /**
     * Keeps the display-only {@code phone} column (used by UserResponse,
     * not for authentication — see V63 migration's doc comment) in sync
     * once a PHONE identity is linked. Never overwrites an existing value:
     * the identity table, not this column, is the source of truth for
     * "which phone can this user log in with".
     */
    public void adoptPhoneIfMissing(String normalizedPhone) {
        if (this.phone == null || this.phone.isBlank()) {
            this.phone = normalizedPhone;
        }
    }
}
