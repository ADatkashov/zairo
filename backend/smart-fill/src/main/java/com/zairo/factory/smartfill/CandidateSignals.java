package com.zairo.factory.smartfill;

/**
 * Everything {@link CandidateFinder} knows about one candidate for one
 * campaign, before any weight is applied -- plain booleans so a {@link
 * CandidateScorer} implementation never has to re-derive them from raw
 * booking/favorite rows itself. A future ML-based scorer would consume the
 * exact same shape (or a superset -- adding a field here is additive, every
 * existing {@code CandidateScorer} just ignores what it doesn't use).
 */
public record CandidateSignals(
        boolean followsProvider,
        boolean previouslyBookedSameEmployee,
        boolean recentlyVisitedProvider,
        boolean previouslyBookedSameService,
        boolean previousProviderBooking,
        boolean categoryInterest,
        boolean suitableHistoricalTime,
        boolean recentEngagement,
        /** See {@link ScoringFactor#DUE_FOR_REBOOKING} -- sourced from {@code customerintelligence.CustomerIntelligenceService}, not derived here. */
        boolean dueForRebooking) {
}
