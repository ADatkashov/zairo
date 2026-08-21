package com.zairo.factory.search;

/**
 * RECOMMENDED is the existing default ranking (open availability first,
 * then distance, then cheapest price) — unchanged by adding explicit sort
 * options. RATING sorts by average rating, highest first (providers with
 * no reviews yet sort last, not first — an absence of ratings shouldn't
 * outrank a genuinely well-reviewed provider); see
 * {@code ReviewSummaryService} for how the rating itself is computed.
 */
public enum SearchSort {
    RECOMMENDED,
    PRICE_ASC,
    PRICE_DESC,
    DISTANCE,
    RATING
}
