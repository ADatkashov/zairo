package com.zairo.factory.customerintelligence;

import java.time.Duration;
import java.time.Instant;

/**
 * Classifies a customer's visit pattern purely from "how long since their
 * last completed visit, compared to their own established cadence" -- no
 * cross-customer comparison, no ML, every threshold configurable (see
 * {@link CustomerIntelligenceProperties.Retention}). Worked example from
 * this module's own task brief: a customer who usually visits every 28 days
 * and hasn't booked in 60 -- that is 2.14x their own interval, past the
 * default {@code atRiskFactor} (2.0) but short of {@code inactiveFactor}
 * (3.0), so this returns {@link RetentionStatus#AT_RISK}.
 */
final class RetentionCalculator {

    private RetentionCalculator() {
    }

    static RetentionStatus classify(Instant lastCompletedBookingAt, Integer averageVisitIntervalDays, Instant now,
            CustomerIntelligenceProperties.Retention config) {
        if (lastCompletedBookingAt == null) {
            return RetentionStatus.NEW;
        }
        long daysSinceLastVisit = Duration.between(lastCompletedBookingAt, now).toDays();

        if (averageVisitIntervalDays == null || averageVisitIntervalDays <= 0) {
            // Not enough visit history to establish a cadence yet -- fall back to flat windows
            // rather than pretending a single visit predicts anything.
            if (daysSinceLastVisit <= config.singleVisitActiveWindowDays()) {
                return RetentionStatus.ACTIVE;
            }
            return daysSinceLastVisit <= config.singleVisitAtRiskWindowDays() ? RetentionStatus.AT_RISK
                    : RetentionStatus.INACTIVE;
        }

        if (daysSinceLastVisit <= averageVisitIntervalDays * config.dueSoonFactor()) {
            return RetentionStatus.ACTIVE;
        }
        if (daysSinceLastVisit <= averageVisitIntervalDays * config.atRiskFactor()) {
            return RetentionStatus.DUE_FOR_REBOOKING;
        }
        if (daysSinceLastVisit <= averageVisitIntervalDays * config.inactiveFactor()) {
            return RetentionStatus.AT_RISK;
        }
        return RetentionStatus.INACTIVE;
    }
}
