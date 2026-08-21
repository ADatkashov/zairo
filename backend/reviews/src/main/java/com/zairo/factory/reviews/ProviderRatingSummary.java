package com.zairo.factory.reviews;

/** Aggregated rating for one provider — see {@link ReviewSummaryService}. */
public record ProviderRatingSummary(double averageRating, long reviewCount) {
}
