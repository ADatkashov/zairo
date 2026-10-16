package com.zairo.factory.reviews;

import java.util.UUID;

/**
 * Published when the platform decides on a review a business reported (or puts a hidden one back); notifications tells
 * the business. {@code providerId} is the business the review is about.
 */
public record ReviewModerationDecidedEvent(UUID reviewId, UUID providerId, Decision decision) {

    public enum Decision {
        /** The review no longer counts anywhere. */
        HIDDEN,
        /** The report was looked at and the review stays. */
        KEPT,
        /** A hidden review counts again. */
        RESTORED
    }
}
