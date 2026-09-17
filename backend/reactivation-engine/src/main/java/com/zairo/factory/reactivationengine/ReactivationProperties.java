package com.zairo.factory.reactivationengine;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code reactivation.*} -- see application.yml for the actual {@code
 * ${ENV_VAR:default}} values. Same "grouped config, not scattered
 * {@code @Value}s" reasoning as {@code rebookengine.RebookProperties}.
 */
@ConfigurationProperties(prefix = "reactivation")
public record ReactivationProperties(int scanMinimumInactivityDays, double intervalMultiplier,
        int absoluteMaxInactivityDays, int followUpWindowDays, double baseProbability) {

    /**
     * Is this many days of inactivity, for a customer with the given
     * established average visit interval (or none), significant enough to
     * count as "lost" rather than just "due" (Rebook's territory)? Either
     * the gap already clears the absolute ceiling regardless of any
     * pattern, or -- once at least two visits establish one -- it clears
     * that customer's own average interval times the configured multiplier.
     */
    boolean isSignificantlyOverdue(long inactiveDays, Long averageIntervalDays) {
        if (inactiveDays >= absoluteMaxInactivityDays) {
            return true;
        }
        return averageIntervalDays != null && inactiveDays >= averageIntervalDays * intervalMultiplier;
    }
}
