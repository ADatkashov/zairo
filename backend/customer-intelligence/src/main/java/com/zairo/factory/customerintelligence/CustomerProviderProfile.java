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
 * The relationship between one customer and one specific business -- unique
 * on ({@code userId}, {@code providerId}). A customer's behaviour with one
 * business can look nothing like their platform-wide {@link CustomerProfile}
 * (a VIP at one salon, a stranger at another), which is exactly why this
 * exists as its own aggregate rather than being derived from the global one.
 * Fully recomputed by {@link CustomerProviderProfileCalculator} -- see that
 * class and this module's own package-info.
 */
@Entity
@Table(name = "customer_provider_profile")
public class CustomerProviderProfile {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "total_bookings", nullable = false)
    private int totalBookings;

    @Column(name = "completed_bookings", nullable = false)
    private int completedBookings;

    @Column(name = "cancelled_bookings", nullable = false)
    private int cancelledBookings;

    @Column(name = "no_shows", nullable = false)
    private int noShows;

    @Column(name = "total_spent", nullable = false)
    private BigDecimal totalSpent;

    @Column(name = "currency")
    private String currency;

    @Column(name = "average_booking_value")
    private BigDecimal averageBookingValue;

    @Column(name = "first_visit_at")
    private Instant firstVisitAt;

    @Column(name = "last_visit_at")
    private Instant lastVisitAt;

    @Column(name = "average_visit_interval_days")
    private Integer averageVisitIntervalDays;

    @Column(name = "next_expected_visit_at")
    private Instant nextExpectedVisitAt;

    /** Comma-separated {@link DayOfWeek} names, most-frequent first. Null if no completed visit yet. */
    @Column(name = "preferred_booking_days")
    private String preferredBookingDays;

    @Enumerated(EnumType.STRING)
    @Column(name = "preferred_time_range", nullable = false)
    private PreferredTimeRange preferredBookingTimeRange;

    @Column(name = "attendance_rate")
    private Double attendanceRate;

    @Column(name = "cancellation_rate", nullable = false)
    private double cancellationRate;

    @Enumerated(EnumType.STRING)
    @Column(name = "retention_status", nullable = false)
    private RetentionStatus retentionStatus;

    /** The employee/master this customer has completed the most bookings with at this business -- opaque id, see {@code AvailabilitySlot.employeeId}. */
    @Column(name = "favourite_employee_id")
    private UUID favouriteEmployeeId;

    @Column(name = "favourite_service_id")
    private UUID favouriteServiceId;

    /** Same 0-100 formula as {@code CustomerProfile.customerValueScore}, scoped to this one business -- see {@link CustomerValueCalculator}. */
    @Column(name = "relationship_score", nullable = false)
    private BigDecimal relationshipScore;

    @Column(name = "last_calculated_at", nullable = false)
    private Instant lastCalculatedAt;

    @Version
    private long version;

    protected CustomerProviderProfile() {
    }

    CustomerProviderProfile(UUID id, UUID userId, UUID providerId) {
        this.id = id;
        this.userId = userId;
        this.providerId = providerId;
        this.totalSpent = BigDecimal.ZERO;
        this.relationshipScore = BigDecimal.ZERO;
        this.preferredBookingTimeRange = PreferredTimeRange.UNKNOWN;
        this.retentionStatus = RetentionStatus.NEW;
    }

    /** {@link CustomerProviderProfileCalculator}'s one write path -- every field is replaced wholesale from a fresh recomputation. */
    void apply(VisitAggregate aggregate, UUID favouriteEmployeeId, UUID favouriteServiceId,
            BigDecimal relationshipScore, Instant now) {
        this.totalBookings = aggregate.totalBookings();
        this.completedBookings = aggregate.completedBookings();
        this.cancelledBookings = aggregate.cancelledBookings();
        this.noShows = aggregate.noShows();
        this.totalSpent = aggregate.totalSpent();
        this.currency = aggregate.currency();
        this.averageBookingValue = aggregate.averageBookingValue();
        this.firstVisitAt = aggregate.firstBookingAt();
        this.lastVisitAt = aggregate.lastCompletedBookingAt();
        this.averageVisitIntervalDays = aggregate.averageVisitIntervalDays();
        this.nextExpectedVisitAt = aggregate.nextExpectedVisitAt();
        this.preferredBookingDays = aggregate.preferredBookingDays().isEmpty() ? null
                : aggregate.preferredBookingDays().stream().map(DayOfWeek::name).reduce((a, b) -> a + "," + b)
                        .orElse(null);
        this.preferredBookingTimeRange = aggregate.preferredBookingTimeRange();
        this.attendanceRate = aggregate.attendanceRate();
        this.cancellationRate = aggregate.cancellationRate();
        this.retentionStatus = aggregate.retentionStatus();
        this.favouriteEmployeeId = favouriteEmployeeId;
        this.favouriteServiceId = favouriteServiceId;
        this.relationshipScore = relationshipScore;
        this.lastCalculatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public int getTotalBookings() {
        return totalBookings;
    }

    public int getCompletedBookings() {
        return completedBookings;
    }

    public int getCancelledBookings() {
        return cancelledBookings;
    }

    public int getNoShows() {
        return noShows;
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

    public Instant getFirstVisitAt() {
        return firstVisitAt;
    }

    public Instant getLastVisitAt() {
        return lastVisitAt;
    }

    public Integer getAverageVisitIntervalDays() {
        return averageVisitIntervalDays;
    }

    public Instant getNextExpectedVisitAt() {
        return nextExpectedVisitAt;
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

    public RetentionStatus getRetentionStatus() {
        return retentionStatus;
    }

    public UUID getFavouriteEmployeeId() {
        return favouriteEmployeeId;
    }

    public UUID getFavouriteServiceId() {
        return favouriteServiceId;
    }

    public BigDecimal getRelationshipScore() {
        return relationshipScore;
    }

    public Instant getLastCalculatedAt() {
        return lastCalculatedAt;
    }
}
