package com.zairo.factory.customerintelligence;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import org.springframework.stereotype.Component;

/**
 * A transparent, deterministic 0-100 estimate of how valuable a customer
 * relationship is -- explicitly not a predicted lifetime value (see this
 * module's own package-info: "no ML model"). Five factors, each normalized
 * to [0, 1] against a configurable cap, blended by configurable weights
 * (normalized against their own sum, so they need not add to 1 -- a
 * misconfigured application.yml still produces a valid 0-100 score instead
 * of a silently wrong one). Reused as-is for all three scopes ({@link
 * CustomerProfile#getCustomerValueScore}, {@link
 * CustomerProviderProfile#getRelationshipScore}, {@link
 * CustomerEmployeeProfile#getRelationshipScore}) -- the formula doesn't
 * care whether "completed bookings" means platform-wide or one business,
 * only the caller does.
 */
@Component
class CustomerValueCalculator {

    private final CustomerIntelligenceProperties properties;

    CustomerValueCalculator(CustomerIntelligenceProperties properties) {
        this.properties = properties;
    }

    BigDecimal score(Inputs inputs) {
        CustomerIntelligenceProperties.Value config = properties.value();

        double bookingsFactor = config.maxCompletedBookingsForScore() <= 0 ? 0
                : Math.min(inputs.completedBookings() / (double) config.maxCompletedBookingsForScore(), 1.0);

        double spentFactor = config.maxTotalSpentForScore() == null || config.maxTotalSpentForScore().signum() <= 0
                || inputs.totalSpent() == null ? 0
                        : Math.min(inputs.totalSpent().doubleValue() / config.maxTotalSpentForScore().doubleValue(),
                                1.0);

        // Attendance is neutral (0.5), not zero, when unknown (no completed-or-no-show history yet) --
        // a brand-new customer shouldn't score as if they were a known flake.
        double attendanceFactor = inputs.attendanceRate() == null ? 0.5 : inputs.attendanceRate();

        double recencyFactor;
        if (inputs.lastCompletedBookingAt() == null || config.recencyWindowDays() <= 0) {
            recencyFactor = 0.0;
        } else {
            long daysSinceLastVisit = Duration.between(inputs.lastCompletedBookingAt(), inputs.now()).toDays();
            recencyFactor = Math.max(0.0, 1.0 - daysSinceLastVisit / (double) config.recencyWindowDays());
        }

        double repeatFactor = inputs.repeatRelationship() ? 1.0 : 0.0;

        double weightSum = config.completedBookingsWeight() + config.totalSpentWeight() + config.attendanceWeight()
                + config.recencyWeight() + config.repeatRelationshipWeight();
        if (weightSum <= 0) {
            return BigDecimal.ZERO;
        }

        double weighted = bookingsFactor * config.completedBookingsWeight()
                + spentFactor * config.totalSpentWeight()
                + attendanceFactor * config.attendanceWeight()
                + recencyFactor * config.recencyWeight()
                + repeatFactor * config.repeatRelationshipWeight();

        return BigDecimal.valueOf(100 * weighted / weightSum).setScale(1, RoundingMode.HALF_UP);
    }

    record Inputs(int completedBookings, BigDecimal totalSpent, Double attendanceRate,
            Instant lastCompletedBookingAt, boolean repeatRelationship, Instant now) {
    }
}
