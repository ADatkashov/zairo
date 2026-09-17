package com.zairo.factory.customerintelligence;

import java.math.BigDecimal;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code customer-intelligence.*} -- see application.yml for the actual
 * {@code ${ENV_VAR:default}} values. Every tunable {@link RetentionCalculator}
 * and {@link CustomerValueCalculator} use lives here, not hardcoded in
 * either class -- same reasoning as {@code smartfill.SmartFillProperties}.
 */
@ConfigurationProperties(prefix = "customer-intelligence")
public record CustomerIntelligenceProperties(Interval interval, Retention retention, Value value) {

    /** How much visit history is needed before an average interval means anything. */
    public record Interval(
            /** Fewer completed visits than this and {@code averageVisitIntervalDays} stays null -- a single visit establishes no cadence. */
            int minCompletedVisitsForInterval) {
    }

    /** See {@link RetentionCalculator} -- every threshold it checks reads one of these. */
    public record Retention(
            /** Days-since-last-visit up to this multiple of the average interval is still {@code ACTIVE}. */
            double dueSoonFactor,
            /** Up to this multiple is {@code DUE_FOR_REBOOKING} rather than {@code AT_RISK}. */
            double atRiskFactor,
            /** Up to this multiple is {@code AT_RISK} rather than {@code INACTIVE}. */
            double inactiveFactor,
            /** No established interval yet (a single visit) -- still {@code ACTIVE} within this many days. */
            int singleVisitActiveWindowDays,
            /** No established interval yet -- {@code AT_RISK} rather than {@code INACTIVE} within this many days. */
            int singleVisitAtRiskWindowDays) {
    }

    /** See {@link CustomerValueCalculator} -- weights are normalized against their own sum, so they need not add to 1. */
    public record Value(
            /** Completed-booking count that alone maxes out the "loyalty" factor. */
            int maxCompletedBookingsForScore,
            /** Lifetime spend that alone maxes out the "spend" factor -- assumes a single currency, see this module's own package-info. */
            BigDecimal maxTotalSpentForScore,
            /** How many days since the last completed visit before the "recency" factor bottoms out at zero. */
            int recencyWindowDays,
            double completedBookingsWeight,
            double totalSpentWeight,
            double attendanceWeight,
            double recencyWeight,
            double repeatRelationshipWeight) {
    }
}
