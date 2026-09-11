package com.zairo.factory.smartfill;

import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * The only {@link CandidateScorer} today: sums {@link
 * SmartFillProperties.Scoring#weights()} for every factor a candidate's
 * {@link CandidateSignals} actually matches. Every factor is additive
 * (a candidate can match several at once) and every weight is configurable
 * -- see application.yml's {@code smartfill.scoring.weights} -- so tuning
 * priority never means touching this class.
 */
@Component
class RuleBasedCandidateScorer implements CandidateScorer {

    private final SmartFillProperties properties;

    RuleBasedCandidateScorer(SmartFillProperties properties) {
        this.properties = properties;
    }

    @Override
    public ScoredCandidate score(UUID userId, CandidateSignals signals) {
        Set<ScoringFactor> matched = EnumSet.noneOf(ScoringFactor.class);
        if (signals.followsProvider()) {
            matched.add(ScoringFactor.FOLLOWS_PROVIDER);
        }
        if (signals.previouslyBookedSameEmployee()) {
            matched.add(ScoringFactor.PREVIOUSLY_BOOKED_SAME_EMPLOYEE);
        }
        if (signals.recentlyVisitedProvider()) {
            matched.add(ScoringFactor.RECENTLY_VISITED_PROVIDER);
        }
        if (signals.previouslyBookedSameService()) {
            matched.add(ScoringFactor.PREVIOUSLY_BOOKED_SAME_SERVICE);
        }
        if (signals.previousProviderBooking()) {
            matched.add(ScoringFactor.PREVIOUS_PROVIDER_BOOKING);
        }
        if (signals.categoryInterest()) {
            matched.add(ScoringFactor.CATEGORY_INTEREST);
        }
        if (signals.suitableHistoricalTime()) {
            matched.add(ScoringFactor.SUITABLE_HISTORICAL_TIME);
        }
        if (signals.recentEngagement()) {
            matched.add(ScoringFactor.RECENT_ENGAGEMENT);
        }

        int total = matched.stream().mapToInt(properties.scoring()::weightOf).sum();
        return new ScoredCandidate(userId, total, matched);
    }
}
