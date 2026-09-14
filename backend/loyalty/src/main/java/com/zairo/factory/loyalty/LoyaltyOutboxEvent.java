package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * A durable record of one {@code booking.BookingCompletedEvent}/{@code
 * reviews.ReviewCreatedEvent} that still needs to be turned into loyalty
 * points -- see this module's own package-info and {@link
 * LoyaltyEarningListener}/{@link LoyaltyOutboxProcessor} for the full
 * "why". Written in the SAME transaction as the booking/review write that
 * caused it (a plain, non-{@code AFTER_COMMIT} listener), so it commits
 * atomically with the fact it records -- a crash right after can never
 * lose it the way a purely in-memory {@code ApplicationEvent} could.
 * {@link LoyaltyOutboxProcessor} is the only thing that ever transitions
 * {@link #status}; nothing else here needs to.
 */
@Entity
@Table(name = "loyalty_outbox_event")
public class LoyaltyOutboxEvent {

    @Id
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false)
    private LoyaltyOutboxEventType eventType;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "booking_id", nullable = false)
    private UUID bookingId;

    /** Only set for {@link LoyaltyOutboxEventType#REVIEW_CREATED}. */
    @Column(name = "review_id")
    private UUID reviewId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LoyaltyOutboxEventStatus status;

    @Column(nullable = false)
    private int attempts;

    @Column(name = "last_error", length = 1000)
    private String lastError;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "processed_at")
    private Instant processedAt;

    protected LoyaltyOutboxEvent() {
    }

    LoyaltyOutboxEvent(UUID id, LoyaltyOutboxEventType eventType, UUID providerId, UUID userId, UUID bookingId,
            UUID reviewId, Instant now) {
        this.id = id;
        this.eventType = eventType;
        this.providerId = providerId;
        this.userId = userId;
        this.bookingId = bookingId;
        this.reviewId = reviewId;
        this.status = LoyaltyOutboxEventStatus.PENDING;
        this.attempts = 0;
        this.createdAt = now;
    }

    void markProcessed(Instant now) {
        this.status = LoyaltyOutboxEventStatus.PROCESSED;
        this.processedAt = now;
    }

    /** Records a failed attempt; caller decides (by attempt count) whether to also call {@link #markFailedPermanently}. */
    void recordFailure(String error) {
        this.attempts += 1;
        this.lastError = error == null ? null : error.substring(0, Math.min(error.length(), 1000));
    }

    void markFailedPermanently() {
        this.status = LoyaltyOutboxEventStatus.FAILED;
    }

    public UUID getId() {
        return id;
    }

    public LoyaltyOutboxEventType getEventType() {
        return eventType;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public UUID getReviewId() {
        return reviewId;
    }

    public LoyaltyOutboxEventStatus getStatus() {
        return status;
    }

    public int getAttempts() {
        return attempts;
    }

    public String getLastError() {
        return lastError;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getProcessedAt() {
        return processedAt;
    }
}
