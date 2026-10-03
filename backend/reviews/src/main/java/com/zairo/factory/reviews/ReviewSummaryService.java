package com.zairo.factory.reviews;

import java.util.Collection;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Entry point other modules use to get provider ratings — callers never
 * touch {@link ReviewRepository}'s aggregate query directly, so the
 * "one query for the whole batch, never per-provider" contract can't be
 * accidentally violated by a caller looping over providers itself.
 *
 * Returns both raw {@code averageRating} (for display) and {@code bayesianRating}
 * (for sorting) — see {@link ProviderRatingSummary} for the distinction.
 */
@Service
public class ReviewSummaryService {

    private final ReviewRepository reviewRepository;
    private final RatingProperties ratingProperties;

    public ReviewSummaryService(ReviewRepository reviewRepository, RatingProperties ratingProperties) {
        this.reviewRepository = reviewRepository;
        this.ratingProperties = ratingProperties;
    }

    /** Providers with no reviews are absent from the returned map, not present with a zero rating. */
    public Map<UUID, ProviderRatingSummary> summarizeRatings(Collection<UUID> providerIds) {
        if (providerIds.isEmpty()) {
            return Map.of();
        }
        int m = ratingProperties.getMinReviewsForConfidence();
        return reviewRepository.aggregateRatingsByProviderIds(providerIds).stream()
                .collect(Collectors.toMap(ReviewRepository.ProviderRatingRow::getProviderId,
                        row -> {
                            double averageRating = row.getAverageRating();
                            long reviewCount = row.getReviewCount();
                            double globalRating = row.getGlobalAverageRating() != null
                                    ? row.getGlobalAverageRating()
                                    : 3.0;
                            double bayesianRating = calculateBayesianRating(averageRating, reviewCount, m,
                                    globalRating);
                            return new ProviderRatingSummary(averageRating, reviewCount, bayesianRating);
                        }));
    }

    /**
     * Bayesian rating formula to prevent single-review bias:
     * {@code weightedRating = (n / (n + m)) * providerRating + (m / (n + m)) * globalRating}
     *
     * Where:
     * - {@code n} = number of provider's reviews
     * - {@code providerRating} = provider's raw average rating
     * - {@code m} = minimum confidence threshold (from configuration)
     * - {@code globalRating} = platform-wide average rating (fallback: 3.0)
     *
     * Example:
     * - Provider A: 5.0 ⭐ (1 review), m=25, global=3.5 → (1/26)*5.0 + (25/26)*3.5 = 3.52
     * - Provider B: 4.0 ⭐ (100 reviews), m=25, global=3.5 → (100/125)*4.0 + (25/125)*3.5 = 3.94
     * Provider B ranks higher despite lower raw rating because of more reviews.
     */
    private double calculateBayesianRating(double providerRating, long reviewCount, int m, double globalRating) {
        if (reviewCount == 0) {
            return globalRating;
        }
        double n = reviewCount;
        return (n / (n + m)) * providerRating + (m / (n + m)) * globalRating;
    }
}
