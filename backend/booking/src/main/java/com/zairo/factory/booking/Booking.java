package com.zairo.factory.booking;

import com.zairo.factory.money.Money;
import com.zairo.factory.payments.DepositType;
import com.zairo.factory.payments.DepositValueType;
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
 * References {@code userId}/{@code serviceId} by id only — booking never
 * imports the users/services module's entity classes, matching the
 * bounded-context boundary in docs/erd/core-domain.md.
 */
@Entity
@Table(name = "booking")
public class Booking {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    @Column(name = "availability_slot_id", nullable = false)
    private UUID availabilitySlotId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BookingStatus status;

    /**
     * Was a bare BigDecimal with no currency of its own (implicitly "the
     * platform default", never actually stored) — now a real Money, backed
     * by a new currency column backfilled from each booking's own service
     * at migration time. See V17__money_value_type.sql and
     * BookingService.createBooking (currency comes from the same platform
     * default config Payment used to configure independently).
     */
    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "amount", column = @Column(name = "total_price", nullable = false)),
            @AttributeOverride(name = "currencyCode", column = @Column(name = "currency", nullable = false))
    })
    private Money totalPrice;

    /** Payment policy for this booking — captured at creation time and immutable */
    @Enumerated(EnumType.STRING)
    @Column(name = "deposit_type", nullable = false)
    private DepositType depositType;

    /** When depositType == DEPOSIT: whether depositValue is percentage or fixed amount */
    @Enumerated(EnumType.STRING)
    @Column(name = "deposit_value_type")
    private DepositValueType depositValueType;

    /** When depositType == DEPOSIT: the percentage (0-100) or fixed amount value */
    @Column(name = "deposit_value", precision = 10, scale = 2)
    private BigDecimal depositValue;

    /** Amount that must be paid as deposit (calculated based on depositType/depositValue) */
    @Column(name = "deposit_amount", precision = 10, scale = 2)
    private BigDecimal depositAmount;

    /** Total amount paid so far (sum of all payments for this booking) */
    @Column(name = "paid_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal paidAmount;

    /** Remaining amount to be paid (totalPrice - paidAmount) */
    @Column(name = "remaining_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal remainingAmount;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** Only ever set by {@link #markCancelled(String)} — null for every other status, including a reasonless cancel. */
    @Column(name = "cancellation_reason")
    private String cancellationReason;

    /** Set once {@link BookingReminderJob} has sent the "your booking is in an hour" reminder — guards against sending it twice. */
    @Column(name = "reminder_sent_at")
    private Instant reminderSentAt;

    /**
     * Optimistic lock — same reasoning as {@code AvailabilitySlot}/{@code
     * payments.Payment}: guards against {@link
     * com.zairo.factory.booking.BookingService#confirmAfterPayment} and
     * {@link com.zairo.factory.booking.BookingService#cancelUnpaidBooking}
     * racing each other (a late webhook confirming a booking the sweep job
     * is simultaneously timing out, or vice versa) under concurrent
     * transactions — without this, both could read PENDING_PAYMENT before
     * either commits and silently double-process it.
     */
    @Version
    private int version;

    protected Booking() {
    }

    public Booking(UUID id, UUID userId, UUID serviceId, UUID availabilitySlotId, BookingStatus status,
            BigDecimal totalPrice, String currency, Instant createdAt) {
        this(id, userId, serviceId, availabilitySlotId, status, totalPrice, currency, createdAt,
                DepositType.NO_PAYMENT, null, null, null);
    }

    public Booking(UUID id, UUID userId, UUID serviceId, UUID availabilitySlotId, BookingStatus status,
            BigDecimal totalPrice, String currency, Instant createdAt, DepositType depositType,
            DepositValueType depositValueType, BigDecimal depositValue, BigDecimal depositAmount) {
        this.id = id;
        this.userId = userId;
        this.serviceId = serviceId;
        this.availabilitySlotId = availabilitySlotId;
        this.status = status;
        this.totalPrice = new Money(totalPrice, currency);
        this.depositType = depositType;
        this.depositValueType = depositValueType;
        this.depositValue = depositValue;
        this.depositAmount = depositAmount != null ? depositAmount : BigDecimal.ZERO;
        this.paidAmount = BigDecimal.ZERO;
        this.remainingAmount = totalPrice;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getServiceId() {
        return serviceId;
    }

    public UUID getAvailabilitySlotId() {
        return availabilitySlotId;
    }

    public BookingStatus getStatus() {
        return status;
    }

    public BigDecimal getTotalPrice() {
        return totalPrice.amount();
    }

    public String getCurrency() {
        return totalPrice.currencyCode();
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public String getCancellationReason() {
        return cancellationReason;
    }

    public Instant getReminderSentAt() {
        return reminderSentAt;
    }

    public DepositType getDepositType() {
        return depositType;
    }

    public DepositValueType getDepositValueType() {
        return depositValueType;
    }

    public BigDecimal getDepositValue() {
        return depositValue;
    }

    public BigDecimal getDepositAmount() {
        return depositAmount;
    }

    public BigDecimal getPaidAmount() {
        return paidAmount;
    }

    public BigDecimal getRemainingAmount() {
        return remainingAmount;
    }

    void markReminderSent(Instant now) {
        this.reminderSentAt = now;
    }

    /** Payment succeeded — PENDING_PAYMENT is the only status this is ever called from, see BookingService. */
    void markConfirmed() {
        this.status = BookingStatus.CONFIRMED;
    }

    void markCompleted() {
        this.status = BookingStatus.COMPLETED;
    }

    void markCancelled(String reason) {
        this.status = BookingStatus.CANCELLED;
        this.cancellationReason = reason;
    }

    void markNoShow() {
        this.status = BookingStatus.NO_SHOW;
    }

    void recordPayment(BigDecimal amount) {
        if (amount != null && amount.compareTo(BigDecimal.ZERO) > 0) {
            this.paidAmount = this.paidAmount.add(amount);
            this.remainingAmount = this.totalPrice.amount().subtract(this.paidAmount);
        }
    }

    boolean isFullyPaid() {
        return this.remainingAmount.compareTo(BigDecimal.ZERO) <= 0;
    }

    boolean hasDepositBeenPaid() {
        if (this.depositType == DepositType.NO_PAYMENT) {
            return true;
        }
        if (this.depositType == DepositType.FULL_PAYMENT) {
            return this.isFullyPaid();
        }
        if (this.depositType == DepositType.DEPOSIT) {
            return this.paidAmount.compareTo(this.depositAmount) >= 0;
        }
        return false;
    }
}
