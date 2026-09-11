package com.zairo.factory.smartfill;

import java.util.UUID;

/**
 * Turns one candidate's {@link CandidateSignals} into a score -- the one
 * seam meant for future ML-based scoring/personalization (see this
 * package's own doc comment): a new implementation of this interface,
 * wired in with {@code @Primary} or a profile, replaces {@link
 * RuleBasedCandidateScorer} without {@link CandidateFinder} or {@link
 * SmartFillCampaignService} changing at all.
 */
public interface CandidateScorer {

    ScoredCandidate score(UUID userId, CandidateSignals signals);
}
