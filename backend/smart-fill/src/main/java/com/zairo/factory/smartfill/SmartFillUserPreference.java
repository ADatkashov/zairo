package com.zairo.factory.smartfill;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * One row per user who has ever changed their Smart Fill opt-in -- absence
 * of a row means "opted in" (see {@link CandidateFinder}'s use of {@link
 * SmartFillUserPreferenceRepository}), same "small table keyed by userId,
 * not a column on {@code users.User}" convention as {@code
 * favorites.Favorite}/{@code subscriptions.Subscription}, and the module
 * boundary those keep: {@code users} owns identity, not every module's
 * opinion about that user.
 */
@Entity
@Table(name = "smart_fill_user_preference")
public class SmartFillUserPreference {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "opted_out", nullable = false)
    private boolean optedOut;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected SmartFillUserPreference() {
    }

    public SmartFillUserPreference(UUID userId, boolean optedOut, Instant updatedAt) {
        this.userId = userId;
        this.optedOut = optedOut;
        this.updatedAt = updatedAt;
    }

    public UUID getUserId() {
        return userId;
    }

    public boolean isOptedOut() {
        return optedOut;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    void update(boolean optedOut, Instant updatedAt) {
        this.optedOut = optedOut;
        this.updatedAt = updatedAt;
    }
}
