package com.zairo.factory.smartfill;

import java.util.Set;
import java.util.UUID;

/** A candidate plus its total score and which factors produced it -- {@link CandidateOffer} persists both. */
public record ScoredCandidate(UUID userId, int score, Set<ScoringFactor> matchedFactors) {
}
