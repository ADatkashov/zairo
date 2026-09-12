package com.zairo.factory.customerintelligence;

/**
 * How a customer's visit pattern with a given scope (platform-wide, or one
 * business) compares to their own established cadence -- see {@link
 * RetentionCalculator} for the actual thresholds, all configurable via
 * {@link CustomerIntelligenceProperties.Retention}. Never drives a
 * notification or marketing action by itself; this is the read, not the
 * reaction (see this module's own package-info).
 */
public enum RetentionStatus {
    /** No completed booking yet -- too little history to say anything about a pattern. */
    NEW,
    /** Within (or comfortably ahead of) their own usual visit interval. */
    ACTIVE,
    /** Their usual interval has just elapsed -- a good moment for a rebooking nudge. */
    DUE_FOR_REBOOKING,
    /** Well past their usual interval -- drifting, not yet written off. */
    AT_RISK,
    /** Far past their usual interval (or a single old visit with no return) -- likely gone. */
    INACTIVE
}
