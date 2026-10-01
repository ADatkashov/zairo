package com.zairo.factory.reviews;

/**
 * Aggregated rating for one provider — see {@link ReviewSummaryService}.
 *
 * {@code averageRating} is the raw user rating for display (what users see: "4.7 ⭐ · 128 reviews").
 * {@code bayesianRating} is the internal Bayesian-smoothed score used for ranking, preventing
 * single-review bias (e.g., a 1-review 5-star provider ranks lower than a 4.5-star provider with 100 reviews).
 */
public record ProviderRatingSummary(
        double averageRating,
        long reviewCount,
        double bayesianRating) {
}

