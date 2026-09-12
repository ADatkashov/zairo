package com.zairo.factory.smartfill;

/**
 * One independently-configurable reason a candidate's score went up --
 * see {@link SmartFillProperties.Scoring#weights()} for the actual numbers
 * (never hardcoded here) and {@link RuleBasedCandidateScorer} for how a
 * {@link CandidateSignals} turns into a set of these. Adding a new factor
 * (e.g. once a "follows this specific employee" feature exists, see
 * CandidateFinder's own doc comment) is: add the constant here, compute the
 * matching boolean/value on {@link CandidateSignals}, add one line to
 * {@link RuleBasedCandidateScorer}, and give it a default weight in
 * application.yml -- nothing else in this module changes.
 */
public enum ScoringFactor {
    /** The candidate has favorited this provider (favorites.Favorite). */
    FOLLOWS_PROVIDER,
    /** The candidate has a previous booking with this exact employee/master (if the slot has one). */
    PREVIOUSLY_BOOKED_SAME_EMPLOYEE,
    /** The candidate's most recent booking with this provider falls within the configured "recent" window. */
    RECENTLY_VISITED_PROVIDER,
    /** The candidate has previously booked this exact service. */
    PREVIOUSLY_BOOKED_SAME_SERVICE,
    /** The candidate has any booking history with this provider at all (baseline "has been here before"). */
    PREVIOUS_PROVIDER_BOOKING,
    /** The candidate has booking history with a different provider sharing this provider's catalog business type. */
    CATEGORY_INTEREST,
    /** The candidate has a history of bookings starting around the same time of day as this slot. */
    SUITABLE_HISTORICAL_TIME,
    /** The candidate has made a booking (anywhere) within the configured recent-engagement window. */
    RECENT_ENGAGEMENT,
    /**
     * Customer Intelligence says this candidate's usual visit interval with
     * this provider has elapsed (retention status {@code DUE_FOR_REBOOKING}
     * or {@code AT_RISK}) -- see {@code customerintelligence.CustomerProviderProfile}.
     * A freed slot is a good opportunity to reach someone who was likely
     * about to book again anyway.
     */
    DUE_FOR_REBOOKING,
}
