package com.zairo.factory.reactivationengine;

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
 * One win-back attempt for a customer the daily discovery sweep found
 * significantly overdue, from the moment the nudge is sent until either
 * they come back or the (longer than Rebook's) follow-up window closes.
 * {@code @Version} gives the same optimistic-locking protection as {@code
 * rebookengine.RebookCampaign} -- a job-sweep run racing {@link
 * ReactivationOutcomeListener} closing the same campaign out resolves to
 * one winner, not a double-send or a lost update.
 */
@Entity
@Table(name = "reactivation_campaign")
public class ReactivationCampaign {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /** Unique -- one campaign per "last visit before they went dark" (see the migration and this module's package-info). */
    @Column(name = "last_visit_booking_id", nullable = false)
    private UUID lastVisitBookingId;

    @Column(name = "last_visit_at", nullable = false)
    private Instant lastVisitAt;

    /** How many days inactive this customer was when the sweep found them -- a snapshot for analytics, not recomputed later. */
    @Column(name = "inactivity_days_at_creation", nullable = false)
    private int inactivityDaysAtCreation;

    /** After the nudge goes out, how long to wait for a rebooking before giving up. */
    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReactivationCampaignStatus status;

    /** Set once the customer actually books again -- see {@link ReactivationOutcomeListener}. */
    @Column(name = "recovered_booking_id")
    private UUID recoveredBookingId;

    /**
     * The customer's last-visit price at campaign creation time -- a
     * snapshot, not a live reference, same "price is a trust invariant
     * captured once" reasoning as {@code rebookengine.RebookCampaign.price}.
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

    protected ReactivationCampaign() {
    }

    public ReactivationCampaign(UUID id, UUID providerId, UUID serviceId, UUID userId, UUID lastVisitBookingId,
            Instant lastVisitAt, int inactivityDaysAtCreation, Instant expiresAt, BigDecimal price, String currency,
            Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.serviceId = serviceId;
        this.userId = userId;
        this.lastVisitBookingId = lastVisitBookingId;
        this.lastVisitAt = lastVisitAt;
        this.inactivityDaysAtCreation = inactivityDaysAtCreation;
        this.expiresAt = expiresAt;
        this.status = ReactivationCampaignStatus.SENT;
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

    public UUID getLastVisitBookingId() {
        return lastVisitBookingId;
    }

    public Instant getLastVisitAt() {
        return lastVisitAt;
    }

    public int getInactivityDaysAtCreation() {
        return inactivityDaysAtCreation;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public ReactivationCampaignStatus getStatus() {
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

    void markBooked(UUID recoveredBookingId, Instant now) {
        this.status = ReactivationCampaignStatus.BOOKED;
        this.recoveredBookingId = recoveredBookingId;
        this.completedAt = now;
    }

    void markExpired(Instant now) {
        this.status = ReactivationCampaignStatus.EXPIRED;
        this.completedAt = now;
    }

    void markCancelled(Instant now) {
        this.status = ReactivationCampaignStatus.CANCELLED;
        this.completedAt = now;
    }

    boolean isActive() {
        return status == ReactivationCampaignStatus.SENT;
    }
}
