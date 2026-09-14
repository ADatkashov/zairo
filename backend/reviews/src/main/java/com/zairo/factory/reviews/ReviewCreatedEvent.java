package com.zairo.factory.reviews;

import java.util.UUID;

/**
 * Published after a customer successfully reviews a completed booking --
 * same in-process domain event pattern as {@code booking}'s own events
 * (ADR-0002). {@code providerId}/{@code userId} are resolved once here
 * (the same booking -> availability slot -> provider hop {@link
 * ReviewService#replyToReview} already does) so a listener never needs to
 * re-derive them itself. Introduced for {@code loyalty}'s review-bonus
 * earning rule; reviews has no dependency on that module and doesn't know
 * it's the one consuming this.
 */
public record ReviewCreatedEvent(UUID reviewId, UUID bookingId, UUID userId, UUID providerId) {
}
