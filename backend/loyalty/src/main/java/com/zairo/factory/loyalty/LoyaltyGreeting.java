package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** One manual greeting a business owner sent to a member -- see V77. Immutable once written. */
@Entity
@Table(name = "loyalty_greeting")
public class LoyaltyGreeting {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false, updatable = false)
    private UUID providerId;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "sent_by_user_id", nullable = false, updatable = false)
    private UUID sentByUserId;

    @Column(length = 500, updatable = false)
    private String message;

    @Column(name = "bonus_points", nullable = false, updatable = false)
    private int bonusPoints;

    @Column(name = "greeting_date", nullable = false, updatable = false)
    private LocalDate greetingDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected LoyaltyGreeting() {
    }

    LoyaltyGreeting(UUID id, UUID providerId, UUID userId, UUID sentByUserId, String message, int bonusPoints,
            LocalDate greetingDate, Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.userId = userId;
        this.sentByUserId = sentByUserId;
        this.message = message;
        this.bonusPoints = bonusPoints;
        this.greetingDate = greetingDate;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getSentByUserId() {
        return sentByUserId;
    }

    public String getMessage() {
        return message;
    }

    public int getBonusPoints() {
        return bonusPoints;
    }

    public LocalDate getGreetingDate() {
        return greetingDate;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
