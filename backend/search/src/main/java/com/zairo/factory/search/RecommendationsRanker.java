package com.zairo.factory.search;

import com.zairo.factory.search.RecommendationsDtos.RecommendedProvider;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Orders businesses for "recommended for you": the categories the customer has actually booked in come first (in
 * proportion to how much), and inside a category the better-rated business wins. Pure and static so the rules are
 * unit-tested without a database.
 */
final class RecommendationsRanker {

    /** How much a customer's share of bookings in a category outweighs a business's rating (both are 0..1). */
    static final double AFFINITY_WEIGHT = 2.0;

    private RecommendationsRanker() {
    }

    /** A business that could be recommended; {@code rating} is its Bayesian average (0..5), or negative if unrated. */
    record Candidate(UUID providerId, String vertical, double rating) {
    }

    /**
     * Only categories the customer has booked in, never a business they have already been to (those are "book
     * again"), best score first; ties by id so the order does not flicker between calls. Empty when there is no
     * booking history to learn from.
     */
    static List<RecommendedProvider> rank(Map<String, Integer> bookingsByVertical, Set<UUID> visitedProviderIds,
            List<Candidate> candidates, int limit) {
        int total = bookingsByVertical.values().stream().mapToInt(Integer::intValue).sum();
        if (total <= 0) {
            return List.of();
        }
        return candidates.stream()
                .filter(c -> bookingsByVertical.getOrDefault(c.vertical(), 0) > 0)
                .filter(c -> !visitedProviderIds.contains(c.providerId()))
                .sorted(Comparator.comparingDouble((Candidate c) -> -score(c, bookingsByVertical, total))
                        .thenComparing(Candidate::providerId))
                .limit(Math.max(limit, 0))
                .map(c -> new RecommendedProvider(c.providerId(), c.vertical()))
                .toList();
    }

    private static double score(Candidate candidate, Map<String, Integer> bookingsByVertical, int total) {
        double affinity = (double) bookingsByVertical.get(candidate.vertical()) / total;
        double rating = candidate.rating() < 0 ? 0 : Math.min(candidate.rating(), 5.0) / 5.0;
        return AFFINITY_WEIGHT * affinity + rating;
    }
}
