package com.zairo.factory.smartfill;

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
 * One freed slot's fill attempt, from the moment its booking is cancelled
 * until it's either re-booked or the attempt is given up on. {@code
 * @Version} gives the same optimistic-locking protection as {@code
 * booking.AvailabilitySlot} -- {@link SmartFillCampaignService} advances a
 * campaign's stage inside a transaction that saves this row, so two
 * notification-job runs (or a job run racing a same-slot booking's close-out)
 * landing on the same campaign resolve to one winner, not a double-send or a
 * lost update; see {@link SmartFillCampaignJob}'s doc comment.
 */
@Entity
@Table(name = "smart_fill_campaign")
public class SmartFillCampaign {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    /** Null if the freed slot wasn't tied to one specific employee -- mirrors {@code AvailabilitySlot.employeeId}. */
    @Column(name = "employee_id")
    private UUID employeeId;

    @Column(name = "availability_slot_id", nullable = false)
    private UUID availabilitySlotId;

    /** Unique -- see V51's migration comment. One campaign per cancelled booking, guaranteed at the DB level. */
    @Column(name = "cancelled_booking_id", nullable = false)
    private UUID cancelledBookingId;

    @Column(name = "slot_starts_at", nullable = false)
    private Instant slotStartsAt;

    @Column(name = "slot_ends_at", nullable = false)
    private Instant slotEndsAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SmartFillCampaignStatus status;

    @Column(name = "current_stage", nullable = false)
    private int currentStage;

    @Column(name = "next_stage_at")
    private Instant nextStageAt;

    /** Set once the slot is actually booked -- may or may not be one of this campaign's own candidates. */
    @Column(name = "recovered_booking_id")
    private UUID recoveredBookingId;

    /**
     * The service's price at campaign creation time -- a snapshot, not a
     * live reference, matching {@code booking.Booking.totalPrice}'s own
     * "price is a trust invariant captured once" reasoning: the recovered-
     * revenue estimate should reflect what this campaign actually could
     * have recovered, not whatever the service happens to cost by the time
     * someone runs an analytics report.
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

    protected SmartFillCampaign() {
    }

    public SmartFillCampaign(UUID id, UUID providerId, UUID serviceId, UUID employeeId, UUID availabilitySlotId,
            UUID cancelledBookingId, Instant slotStartsAt, Instant slotEndsAt, BigDecimal price, String currency,
            Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.serviceId = serviceId;
        this.employeeId = employeeId;
        this.availabilitySlotId = availabilitySlotId;
        this.cancelledBookingId = cancelledBookingId;
        this.slotStartsAt = slotStartsAt;
        this.slotEndsAt = slotEndsAt;
        this.status = SmartFillCampaignStatus.CREATED;
        this.currentStage = 0;
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

    public UUID getEmployeeId() {
        return employeeId;
    }

    public UUID getAvailabilitySlotId() {
        return availabilitySlotId;
    }

    public UUID getCancelledBookingId() {
        return cancelledBookingId;
    }

    public Instant getSlotStartsAt() {
        return slotStartsAt;
    }

    public Instant getSlotEndsAt() {
        return slotEndsAt;
    }

    public SmartFillCampaignStatus getStatus() {
        return status;
    }

    public int getCurrentStage() {
        return currentStage;
    }

    public Instant getNextStageAt() {
        return nextStageAt;
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

    /** Moves from CREATED/SEARCHING into NOTIFYING and schedules the next stage check. */
    void markStageSent(int stage, Instant nextStageAt) {
        this.status = SmartFillCampaignStatus.NOTIFYING;
        this.currentStage = stage;
        this.nextStageAt = nextStageAt;
    }

    /** Also clears {@code completedAt} -- a no-op the first time (always null then), but required for {@link SmartFillCampaignService#retryCampaign} reviving an EXPIRED campaign. */
    void markSearching() {
        this.status = SmartFillCampaignStatus.SEARCHING;
        this.completedAt = null;
    }

    void markBooked(UUID recoveredBookingId, Instant now) {
        this.status = SmartFillCampaignStatus.BOOKED;
        this.recoveredBookingId = recoveredBookingId;
        this.nextStageAt = null;
        this.completedAt = now;
    }

    void markExpired(Instant now) {
        this.status = SmartFillCampaignStatus.EXPIRED;
        this.nextStageAt = null;
        this.completedAt = now;
    }

    /** Only reachable from NOTIFYING -- see {@link SmartFillCampaignService#pauseCampaign}. */
    void markPaused() {
        this.status = SmartFillCampaignStatus.PAUSED;
        this.nextStageAt = null;
    }

    /** Resumes staging at the next stage, as if this stage had just been sent -- see {@link SmartFillCampaignService#resumeCampaign}. */
    void markResumed(Instant nextStageAt) {
        this.status = SmartFillCampaignStatus.NOTIFYING;
        this.nextStageAt = nextStageAt;
    }

    void markCancelled(Instant now) {
        this.status = SmartFillCampaignStatus.CANCELLED;
        this.nextStageAt = null;
        this.completedAt = now;
    }

    boolean isActive() {
        return status == SmartFillCampaignStatus.CREATED || status == SmartFillCampaignStatus.SEARCHING
                || status == SmartFillCampaignStatus.NOTIFYING;
    }
}
