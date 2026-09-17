package com.zairo.factory.rebookengine;

import com.zairo.factory.money.Money;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * One customer's "are they due for another visit" watch, from the moment a
 * booking of theirs completes until either they come back or the follow-up
 * window closes. {@code @Version} gives the same optimistic-locking
 * protection as {@code smartfill.SmartFillCampaign} -- a job-sweep run
 * racing {@link RebookOutcomeListener} closing the same campaign out
 * resolves to one winner, not a double-send or a lost update.
 */
@Entity
@Table(name = "rebook_campaign")
public class RebookCampaign {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /** Unique -- one campaign per completed booking, guaranteed at the DB level (see the migration). */
    @Column(name = "completed_booking_id", nullable = false)
    private UUID completedBookingId;

    /** The most recent visit's slot start time, the anchor {@code dueAt} is computed from. */
    @Column(name = "last_visit_at", nullable = false)
    private Instant lastVisitAt;

    /** The customer's average gap between visits with this provider, clamped to a sane range -- see {@link RebookProperties}. */
    @Column(name = "average_interval_days", nullable = false)
    private int averageIntervalDays;

    @Column(name = "due_at", nullable = false)
    private Instant dueAt;

    /** After the nudge goes out, how long to wait for a rebooking before giving up. */
    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RebookCampaignStatus status;

    /** Set once the customer actually books again -- see {@link RebookOutcomeListener}. */
    @Column(name = "recovered_booking_id")
    private UUID recoveredBookingId;

    /**
     * The completed booking's price at campaign creation time -- a
     * snapshot, not a live reference, same "price is a trust invariant
     * captured once" reasoning as {@code smartfill.SmartFillCampaign.price}.
     */
    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "price_amount", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "price_currency", nullable = false))
    })
    private Money price;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Version
    private long version;

    protected RebookCampaign() {
    }

    public RebookCampaign(UUID id, UUID providerId, UUID serviceId, UUID userId, UUID completedBookingId,
            Instant lastVisitAt, int averageIntervalDays, Instant dueAt, Instant expiresAt, BigDecimal price,
            String currency, Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.serviceId = serviceId;
        this.userId = userId;
        this.completedBookingId = completedBookingId;
        this.lastVisitAt = lastVisitAt;
        this.averageIntervalDays = averageIntervalDays;
        this.dueAt = dueAt;
        this.expiresAt = expiresAt;
        this.status = RebookCampaignStatus.CREATED;
        this.price = new Money(price, currency);
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public UUID getServiceId() {
        return serviceId;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getCompletedBookingId() {
        return completedBookingId;
    }

    public Instant getLastVisitAt() {
        return lastVisitAt;
    }

    public int getAverageIntervalDays() {
        return averageIntervalDays;
    }

    public Instant getDueAt() {
        return dueAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public RebookCampaignStatus getStatus() {
        return status;
    }

    public UUID getRecoveredBookingId() {
        return recoveredBookingId;
    }

    public BigDecimal getPriceAmount() {
        return price.amount();
    }

    public String getPriceCurrency() {
        return price.currencyCode();
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getCompletedAt() {
        return completedAt;
    }

    void markOffered(Instant now) {
        this.status = RebookCampaignStatus.OFFERED;
    }

    void markBooked(UUID recoveredBookingId, Instant now) {
        this.status = RebookCampaignStatus.BOOKED;
        this.recoveredBookingId = recoveredBookingId;
        this.completedAt = now;
    }

    void markExpired(Instant now) {
        this.status = RebookCampaignStatus.EXPIRED;
        this.completedAt = now;
    }

    void markCancelled(Instant now) {
        this.status = RebookCampaignStatus.CANCELLED;
        this.completedAt = now;
    }

    boolean isActive() {
        return status == RebookCampaignStatus.CREATED || status == RebookCampaignStatus.OFFERED;
    }
}
