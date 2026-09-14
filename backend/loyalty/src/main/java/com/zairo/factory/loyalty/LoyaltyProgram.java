package com.zairo.factory.loyalty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * One business's own loyalty configuration -- unique on {@code providerId}.
 * Disabled by default (see {@link LoyaltyProgramService#getOrCreateDraft}):
 * a provider with no row, or a row with {@code enabled=false}, behaves
 * exactly like the platform did before this module existed -- no points
 * are ever earned or shown (see this module's package-info, Phase 29
 * backward compatibility).
 *
 * <p>Earning rules are independent and additive: {@code fixedPointsPerBooking}
 * and {@code pointsPerCurrencyUnit} can both be set (a flat rate plus a
 * spend-based rate) or either can be left at zero to disable that half of
 * the rule -- the business isn't forced into exactly one shape.
 */
@Entity
@Table(name = "loyalty_program")
public class LoyaltyProgram {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false, unique = true)
    private UUID providerId;

    @Column(nullable = false)
    private boolean enabled;

    @Column(nullable = false)
    private String name;

    @Column
    private String description;

    /** Flat points awarded per completed booking, regardless of price. Zero disables this half of the earning rule. */
    @Column(name = "fixed_points_per_booking", nullable = false)
    private int fixedPointsPerBooking;

    /** Points earned per one unit of the booking's own currency spent (e.g. 1.00 = "1 point per 1 spent"). Zero disables it. */
    @Column(name = "points_per_currency_unit", nullable = false)
    private BigDecimal pointsPerCurrencyUnit;

    /** Awarded once, on a customer's first completed booking with this business. Zero/absent disables it. */
    @Column(name = "first_booking_bonus_points", nullable = false)
    private int firstBookingBonusPoints;

    /** Awarded once, when a customer reaches {@link #repeatVisitThreshold} completed bookings. */
    @Column(name = "repeat_visit_bonus_points", nullable = false)
    private int repeatVisitBonusPoints;

    /** Which completed-booking count counts as "a repeat visit" -- defaults to the 2nd. */
    @Column(name = "repeat_visit_threshold", nullable = false)
    private int repeatVisitThreshold;

    /** Awarded once per booking when the customer leaves a review for it. Zero disables it. */
    @Column(name = "review_bonus_points", nullable = false)
    private int reviewBonusPoints;

    /**
     * Informational only -- surfaced to the business when pricing a new
     * reward (e.g. "customers redeem about 10 points per 1 spent"); never
     * enforced server-side, since each {@link LoyaltyReward} sets its own
     * discount value directly. Null if the business hasn't set a guideline.
     */
    @Column(name = "points_per_currency_unit_redemption")
    private BigDecimal pointsPerCurrencyUnitRedemption;

    /** A customer's available balance must be at least this to redeem anything. Null = no minimum. */
    @Column(name = "min_redemption_points")
    private Integer minRedemptionPoints;

    /** Total points that may be spent across every reward applied to one booking. Null = no cap. */
    @Column(name = "max_redemption_points_per_booking")
    private Integer maxRedemptionPointsPerBooking;

    @Column(name = "points_expire_enabled", nullable = false)
    private boolean pointsExpireEnabled;

    /** Months after earning that a point expires. Required (and only meaningful) when {@link #pointsExpireEnabled}. */
    @Column(name = "points_expiration_months")
    private Integer pointsExpirationMonths;

    /** Ceiling on EARNED+BONUS points a single account may accrue per rolling 24h. Null = no cap. */
    @Column(name = "daily_earning_points_cap")
    private Integer dailyEarningPointsCap;

    /** Ceiling on EARNED+BONUS points a single account may accrue per rolling 30 days. Null = no cap. */
    @Column(name = "monthly_earning_points_cap")
    private Integer monthlyEarningPointsCap;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    private long version;

    protected LoyaltyProgram() {
    }

    LoyaltyProgram(UUID id, UUID providerId, String name, Instant now) {
        this.id = id;
        this.providerId = providerId;
        this.name = name;
        this.enabled = false;
        this.fixedPointsPerBooking = 0;
        this.pointsPerCurrencyUnit = BigDecimal.ZERO;
        this.firstBookingBonusPoints = 0;
        this.repeatVisitBonusPoints = 0;
        this.repeatVisitThreshold = 2;
        this.reviewBonusPoints = 0;
        this.pointsExpireEnabled = false;
        this.createdAt = now;
        this.updatedAt = now;
    }

    void applySettings(boolean enabled, String name, String description, int fixedPointsPerBooking,
            BigDecimal pointsPerCurrencyUnit, int firstBookingBonusPoints, int repeatVisitBonusPoints,
            int repeatVisitThreshold, int reviewBonusPoints, BigDecimal pointsPerCurrencyUnitRedemption,
            Integer minRedemptionPoints, Integer maxRedemptionPointsPerBooking, boolean pointsExpireEnabled,
            Integer pointsExpirationMonths, Integer dailyEarningPointsCap, Integer monthlyEarningPointsCap,
            Instant now) {
        this.enabled = enabled;
        this.name = name;
        this.description = description;
        this.fixedPointsPerBooking = fixedPointsPerBooking;
        this.pointsPerCurrencyUnit = pointsPerCurrencyUnit;
        this.firstBookingBonusPoints = firstBookingBonusPoints;
        this.repeatVisitBonusPoints = repeatVisitBonusPoints;
        this.repeatVisitThreshold = repeatVisitThreshold;
        this.reviewBonusPoints = reviewBonusPoints;
        this.pointsPerCurrencyUnitRedemption = pointsPerCurrencyUnitRedemption;
        this.minRedemptionPoints = minRedemptionPoints;
        this.maxRedemptionPointsPerBooking = maxRedemptionPointsPerBooking;
        this.pointsExpireEnabled = pointsExpireEnabled;
        this.pointsExpirationMonths = pointsExpirationMonths;
        this.dailyEarningPointsCap = dailyEarningPointsCap;
        this.monthlyEarningPointsCap = monthlyEarningPointsCap;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public int getFixedPointsPerBooking() {
        return fixedPointsPerBooking;
    }

    public BigDecimal getPointsPerCurrencyUnit() {
        return pointsPerCurrencyUnit;
    }

    public int getFirstBookingBonusPoints() {
        return firstBookingBonusPoints;
    }

    public int getRepeatVisitBonusPoints() {
        return repeatVisitBonusPoints;
    }

    public int getRepeatVisitThreshold() {
        return repeatVisitThreshold;
    }

    public int getReviewBonusPoints() {
        return reviewBonusPoints;
    }

    public BigDecimal getPointsPerCurrencyUnitRedemption() {
        return pointsPerCurrencyUnitRedemption;
    }

    public Integer getMinRedemptionPoints() {
        return minRedemptionPoints;
    }

    public Integer getMaxRedemptionPointsPerBooking() {
        return maxRedemptionPointsPerBooking;
    }

    public boolean isPointsExpireEnabled() {
        return pointsExpireEnabled;
    }

    public Integer getPointsExpirationMonths() {
        return pointsExpirationMonths;
    }

    public Integer getDailyEarningPointsCap() {
        return dailyEarningPointsCap;
    }

    public Integer getMonthlyEarningPointsCap() {
        return monthlyEarningPointsCap;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
