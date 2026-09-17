package com.zairo.factory.customerintelligence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * The relationship between one customer and one specific employee/master --
 * unique on ({@code userId}, {@code providerId}, {@code employeeId}). The
 * lightest of the three aggregates (see this module's own package-info) --
 * exactly the signal Smart Fill's {@code PREVIOUSLY_BOOKED_SAME_EMPLOYEE}
 * factor stands in for today with a cheap existence check; this is the real
 * relationship behind it. Fully recomputed by {@link
 * CustomerEmployeeProfileCalculator}.
 */
@Entity
@Table(name = "customer_employee_profile")
public class CustomerEmployeeProfile {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    @Column(name = "completed_bookings", nullable = false)
    private int completedBookings;

    @Column(name = "total_spent", nullable = false)
    private BigDecimal totalSpent;

    @Column(name = "currency")
    private String currency;

    @Column(name = "last_visit_at")
    private Instant lastVisitAt;

    @Column(name = "average_visit_interval_days")
    private Integer averageVisitIntervalDays;

    @Column(name = "favourite_service_id")
    private UUID favouriteServiceId;

    /** Same 0-100 formula as {@code CustomerProviderProfile.relationshipScore}, scoped to this one employee. */
    @Column(name = "relationship_score", nullable = false)
    private BigDecimal relationshipScore;

    @Column(name = "last_calculated_at", nullable = false)
    private Instant lastCalculatedAt;

    @Version
    private long version;

    protected CustomerEmployeeProfile() {
    }

    CustomerEmployeeProfile(UUID id, UUID userId, UUID providerId, UUID employeeId) {
        this.id = id;
        this.userId = userId;
        this.providerId = providerId;
        this.employeeId = employeeId;
        this.totalSpent = BigDecimal.ZERO;
        this.relationshipScore = BigDecimal.ZERO;
    }

    void apply(int completedBookings, BigDecimal totalSpent, String currency, Instant lastVisitAt,
            Integer averageVisitIntervalDays, UUID favouriteServiceId, BigDecimal relationshipScore, Instant now) {
        this.completedBookings = completedBookings;
        this.totalSpent = totalSpent;
        this.currency = currency;
        this.lastVisitAt = lastVisitAt;
        this.averageVisitIntervalDays = averageVisitIntervalDays;
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

    public UUID getEmployeeId() {
        return employeeId;
    }

    public int getCompletedBookings() {
        return completedBookings;
    }

    public BigDecimal getTotalSpent() {
        return totalSpent;
    }

    public String getCurrency() {
        return currency;
    }

    public Instant getLastVisitAt() {
        return lastVisitAt;
    }

    public Integer getAverageVisitIntervalDays() {
        return averageVisitIntervalDays;
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
