package com.zairo.factory.reviews;

import java.time.Instant;
import java.util.UUID;

public final class ReviewDtos {

    private ReviewDtos() {
    }

    public record CreateReviewRequest(int rating, String comment) {
    }

    public record ReviewResponse(UUID id, UUID bookingId, int rating, String comment, Instant createdAt) {
        static ReviewResponse from(Review review) {
            return new ReviewResponse(review.getId(), review.getBookingId(), review.getRating(),
                    review.getComment(), review.getCreatedAt());
        }
    }
}
