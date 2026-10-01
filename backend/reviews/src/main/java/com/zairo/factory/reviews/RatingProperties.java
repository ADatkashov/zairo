package com.zairo.factory.reviews;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Configuration for Bayesian rating calculation (see {@link ReviewSummaryService}).
 * Injected via {@link org.springframework.boot.context.properties.EnableConfigurationProperties}.
 */
@Component
@ConfigurationProperties(prefix = "rating.bayesian")
public class RatingProperties {

    /**
     * Minimum review count (m) for Bayesian averaging. A provider with fewer
     * reviews gets pulled toward the global average rating to prevent single-
     * or few-review bias from inflating rankings.
     *
     * Default: 25 — a provider needs roughly 25 reviews to fully trust their own average.
     */
    private int minReviewsForConfidence = 25;

    public int getMinReviewsForConfidence() {
        return minReviewsForConfidence;
    }

    public void setMinReviewsForConfidence(int minReviewsForConfidence) {
        this.minReviewsForConfidence = minReviewsForConfidence;
    }
}
