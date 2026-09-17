package com.zairo.factory.customerintelligence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * One customer's behaviour across every business on the platform --
 * {@code userId} is unique. Fully recomputed by {@link
 * CustomerProfileCalculator} on every relevant booking event, never
 * mutated incrementally (see this module's own package-info on why). Money
 * fields assume a single currency across every provider a customer has
 * booked with (no exchange-rate conversion exists in this codebase yet --
 * see {@code money}'s own package-info) -- {@code currency} is simply the
 * first non-null currency seen among completed bookings.
 */
@Entity
@Table(name = "customer_profile")
public class CustomerProfile {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false, unique = true)
    private UUID userId;

    @Column(name = "total_completed_bookings", nullable = false)
    private int totalCompletedBookings;

    @Column(name = "total_cancelled_bookings", nullable = false)
    private int totalCancelledBookings;

    @Column(name = "total_no_shows", nullable = false)
    private int totalNoShows;

    @Column(name = "total_spent", nullable = false)
    private BigDecimal totalSpent;

    @Column(name = "currency")
    private String currency;

    @Column(name = "average_booking_value")
    private BigDecimal averageBookingValue;

    @Column(name = "first_booking_at")
    private Instant firstBookingAt;

    @Column(name = "last_booking_at")
    private Instant lastBookingAt;

    @Column(name = "last_completed_booking_at")
    private Instant lastCompletedBookingAt;

    @Column(name = "average_visit_interval_days")
    private Integer averageVisitIntervalDays;

    /** Comma-separated {@link DayOfWeek} names, most-frequent first -- e.g. {@code "FRIDAY,SATURDAY"}. Null if no completed booking yet. */
    @Column(name = "preferred_booking_days")
    private String preferredBookingDays;

    @Enumerated(EnumType.STRING)
    @Column(name = "preferred_time_range", nullable = false)
    private PreferredTimeRange preferredBookingTimeRange;

    @Column(name = "attendance_rate")
    private Double attendanceRate;

    @Column(name = "cancellation_rate", nullable = false)
    private double cancellationRate;

    @Column(name = "repeat_booking_rate", nullable = false)
    private double repeatBookingRate;

    @Column(name = "customer_value_score", nullable = false)
    private BigDecimal customerValueScore;

    @Column(name = "next_expected_visit_at")
    private Instant nextExpectedVisitAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "retention_status", nullable = false)
    private RetentionStatus retentionStatus;

    @Column(name = "favourite_provider_id")
    private UUID favouriteProviderId;

    @Column(name = "favourite_service_id")
    private UUID favouriteServiceId;

    @Column(name = "last_calculated_at", nullable = false)
    private Instant lastCalculatedAt;

    @Version
    private long version;

    protected CustomerProfile() {
    }

    CustomerProfile(UUID id, UUID userId) {
        this.id = id;
        this.userId = userId;
        this.totalSpent = BigDecimal.ZERO;
        this.customerValueScore = BigDecimal.ZERO;
        this.preferredBookingTimeRange = PreferredTimeRange.UNKNOWN;
        this.retentionStatus = RetentionStatus.NEW;
    }

    /** {@link CustomerProfileCalculator}'s one write path -- every field is replaced wholesale from a fresh recomputation. */
    void apply(VisitAggregate aggregate, double repeatBookingRate, UUID favouriteProviderId, UUID favouriteServiceId,
            BigDecimal customerValueScore, Instant now) {
        this.totalCompletedBookings = aggregate.completedBookings();
        this.totalCancelledBookings = aggregate.cancelledBookings();
        this.totalNoShows = aggregate.noShows();
        this.totalSpent = aggregate.totalSpent();
        this.currency = aggregate.currency();
        this.averageBookingValue = aggregate.averageBookingValue();
        this.firstBookingAt = aggregate.firstBookingAt();
        this.lastBookingAt = aggregate.lastBookingAt();
        this.lastCompletedBookingAt = aggregate.lastCompletedBookingAt();
        this.averageVisitIntervalDays = aggregate.averageVisitIntervalDays();
        this.preferredBookingDays = joinDays(aggregate.preferredBookingDays());
        this.preferredBookingTimeRange = aggregate.preferredBookingTimeRange();
        this.attendanceRate = aggregate.attendanceRate();
        this.cancellationRate = aggregate.cancellationRate();
        this.repeatBookingRate = repeatBookingRate;
        this.customerValueScore = customerValueScore;
        this.nextExpectedVisitAt = aggregate.nextExpectedVisitAt();
        this.retentionStatus = aggregate.retentionStatus();
        this.favouriteProviderId = favouriteProviderId;
        this.favouriteServiceId = favouriteServiceId;
        this.lastCalculatedAt = now;
    }

    private static String joinDays(List<DayOfWeek> days) {
        return days.isEmpty() ? null : days.stream().map(DayOfWeek::name).reduce((a, b) -> a + "," + b).orElse(null);
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public int getTotalCompletedBookings() {
        return totalCompletedBookings;
    }

    public int getTotalCancelledBookings() {
        return totalCancelledBookings;
    }

    public int getTotalNoShows() {
        return totalNoShows;
    }

    public BigDecimal getTotalSpent() {
        return totalSpent;
    }

    public String getCurrency() {
        return currency;
    }

    public BigDecimal getAverageBookingValue() {
        return averageBookingValue;
    }

    public Instant getFirstBookingAt() {
        return firstBookingAt;
    }

    public Instant getLastBookingAt() {
        return lastBookingAt;
    }

    public Instant getLastCompletedBookingAt() {
        return lastCompletedBookingAt;
    }

    public Integer getAverageVisitIntervalDays() {
        return averageVisitIntervalDays;
    }

    public List<DayOfWeek> getPreferredBookingDays() {
        return preferredBookingDays == null ? List.of()
                : List.of(preferredBookingDays.split(",")).stream().map(DayOfWeek::valueOf).toList();
    }

    public PreferredTimeRange getPreferredBookingTimeRange() {
        return preferredBookingTimeRange;
    }

    public Double getAttendanceRate() {
        return attendanceRate;
    }

    public double getCancellationRate() {
        return cancellationRate;
    }

    public double getRepeatBookingRate() {
        return repeatBookingRate;
    }

    public BigDecimal getCustomerValueScore() {
        return customerValueScore;
    }

    public Instant getNextExpectedVisitAt() {
        return nextExpectedVisitAt;
    }

    public RetentionStatus getRetentionStatus() {
        return retentionStatus;
    }

    public UUID getFavouriteProviderId() {
        return favouriteProviderId;
    }

    public UUID getFavouriteServiceId() {
        return favouriteServiceId;
    }

    public Instant getLastCalculatedAt() {
        return lastCalculatedAt;
    }
}
