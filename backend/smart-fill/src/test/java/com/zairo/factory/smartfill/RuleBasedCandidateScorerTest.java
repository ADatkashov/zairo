package com.zairo.factory.smartfill;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.EnumMap;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit test -- the scorer only sums configured weights over the matched signals. */
class RuleBasedCandidateScorerTest {

    private static final UUID USER = UUID.randomUUID();

    private static RuleBasedCandidateScorer scorer(Map<ScoringFactor, Integer> weights) {
        SmartFillProperties props = new SmartFillProperties(null, null,
                new SmartFillProperties.Scoring(90, 30, 60, weights));
        return new RuleBasedCandidateScorer(props);
    }

    private static Map<ScoringFactor, Integer> allWeights(int each) {
        Map<ScoringFactor, Integer> w = new EnumMap<>(ScoringFactor.class);
        for (ScoringFactor f : ScoringFactor.values()) {
            w.put(f, each);
        }
        return w;
    }

    private static CandidateSignals none() {
        return new CandidateSignals(false, false, false, false, false, false, false, false, false);
    }

    @Test
    void aCandidateMatchingNothingScoresZeroWithNoFactors() {
        ScoredCandidate c = scorer(allWeights(10)).score(USER, none());

        assertThat(c.userId()).isEqualTo(USER);
        assertThat(c.score()).isZero();
        assertThat(c.matchedFactors()).isEmpty();
    }

    @Test
    void aCandidateMatchingEverythingScoresTheSumOfAllWeights() {
        CandidateSignals all = new CandidateSignals(true, true, true, true, true, true, true, true, true);

        ScoredCandidate c = scorer(allWeights(10)).score(USER, all);

        assertThat(c.matchedFactors()).containsExactlyInAnyOrder(ScoringFactor.values());
        assertThat(c.score()).isEqualTo(10 * ScoringFactor.values().length);
    }

    @Test
    void onlyMatchedFactorsContributeAndEachUsesItsOwnWeight() {
        Map<ScoringFactor, Integer> weights = allWeights(0);
        weights.put(ScoringFactor.FOLLOWS_PROVIDER, 30);
        weights.put(ScoringFactor.DUE_FOR_REBOOKING, 7);
        weights.put(ScoringFactor.CATEGORY_INTEREST, 1000);
        CandidateSignals signals = new CandidateSignals(true, false, false, false, false, false, false, false, true);

        ScoredCandidate c = scorer(weights).score(USER, signals);

        assertThat(c.matchedFactors()).containsExactlyInAnyOrder(ScoringFactor.FOLLOWS_PROVIDER,
                ScoringFactor.DUE_FOR_REBOOKING);
        assertThat(c.score()).isEqualTo(37);
    }

    @Test
    void aMatchedFactorWithoutAConfiguredWeightScoresZeroInsteadOfFailing() {
        CandidateSignals signals = new CandidateSignals(true, false, false, false, false, false, false, false, false);

        ScoredCandidate c = scorer(Map.of()).score(USER, signals);

        assertThat(c.matchedFactors()).containsExactly(ScoringFactor.FOLLOWS_PROVIDER);
        assertThat(c.score()).isZero();
    }

    @Test
    void everySignalMapsToItsOwnFactor() {
        assertThat(factorsFor(new CandidateSignals(true, false, false, false, false, false, false, false, false)))
                .containsExactly(ScoringFactor.FOLLOWS_PROVIDER);
        assertThat(factorsFor(new CandidateSignals(false, true, false, false, false, false, false, false, false)))
                .containsExactly(ScoringFactor.PREVIOUSLY_BOOKED_SAME_EMPLOYEE);
        assertThat(factorsFor(new CandidateSignals(false, false, true, false, false, false, false, false, false)))
                .containsExactly(ScoringFactor.RECENTLY_VISITED_PROVIDER);
        assertThat(factorsFor(new CandidateSignals(false, false, false, true, false, false, false, false, false)))
                .containsExactly(ScoringFactor.PREVIOUSLY_BOOKED_SAME_SERVICE);
        assertThat(factorsFor(new CandidateSignals(false, false, false, false, true, false, false, false, false)))
                .containsExactly(ScoringFactor.PREVIOUS_PROVIDER_BOOKING);
        assertThat(factorsFor(new CandidateSignals(false, false, false, false, false, true, false, false, false)))
                .containsExactly(ScoringFactor.CATEGORY_INTEREST);
        assertThat(factorsFor(new CandidateSignals(false, false, false, false, false, false, true, false, false)))
                .containsExactly(ScoringFactor.SUITABLE_HISTORICAL_TIME);
        assertThat(factorsFor(new CandidateSignals(false, false, false, false, false, false, false, true, false)))
                .containsExactly(ScoringFactor.RECENT_ENGAGEMENT);
        assertThat(factorsFor(new CandidateSignals(false, false, false, false, false, false, false, false, true)))
                .containsExactly(ScoringFactor.DUE_FOR_REBOOKING);
    }

    private static java.util.Set<ScoringFactor> factorsFor(CandidateSignals signals) {
        return scorer(allWeights(1)).score(USER, signals).matchedFactors();
    }
}
