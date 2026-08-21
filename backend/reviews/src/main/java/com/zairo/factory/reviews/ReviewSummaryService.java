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
 */
@Service
public class ReviewSummaryService {

    private final ReviewRepository reviewRepository;

    public ReviewSummaryService(ReviewRepository reviewRepository) {
        this.reviewRepository = reviewRepository;
    }

    /** Providers with no reviews are absent from the returned map, not present with a zero rating. */
    public Map<UUID, ProviderRatingSummary> summarizeRatings(Collection<UUID> providerIds) {
        if (providerIds.isEmpty()) {
            return Map.of();
        }
        return reviewRepository.aggregateRatingsByProviderIds(providerIds).stream()
                .collect(Collectors.toMap(ReviewRepository.ProviderRatingRow::getProviderId,
                        row -> new ProviderRatingSummary(row.getAverageRating(), row.getReviewCount())));
    }
}
