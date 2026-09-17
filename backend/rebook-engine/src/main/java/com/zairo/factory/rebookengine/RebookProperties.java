package com.zairo.factory.rebookengine;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code rebook.*} -- see application.yml for the actual {@code
 * ${ENV_VAR:default}} values. Same "grouped config, not scattered
 * {@code @Value}s" reasoning as {@code smartfill.SmartFillProperties}.
 */
@ConfigurationProperties(prefix = "rebook")
public record RebookProperties(int minVisitsToEstablishInterval, int minIntervalDays, int maxIntervalDays,
        int followUpWindowDays, double baseProbability) {

    /**
     * Clamps a raw computed average gap (in days) into a sane range --
     * without this, one outlier pair of visits years apart (e.g. a customer
     * who came back after a long absence) could predict an absurd interval
     * for everyone after them.
     */
    int clamp(long averageGapDays) {
        return (int) Math.min(maxIntervalDays, Math.max(minIntervalDays, averageGapDays));
    }
}
