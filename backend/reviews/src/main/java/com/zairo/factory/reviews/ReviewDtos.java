package com.zairo.factory.reviews;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class ReviewDtos {

    private ReviewDtos() {
    }

    // 1-5 mirrors the exact range ReviewService.createReview already
    // enforces (as a proper 400) — duplicated here only so springdoc/Swagger
    // can show the bound in the schema and reject it a step earlier.
    public record CreateReviewRequest(
            @Min(1) @Max(5) @Schema(example = "5") int rating,
            @Schema(description = "Optional.", example = "Loved the service!") String comment) {
    }

    public record ReplyToReviewRequest(
            @NotBlank @Size(max = 2000) @Schema(example = "Thank you for the kind words!") String reply) {
    }

    public record ReviewResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            @Schema(example = "5") int rating,
            @Schema(example = "Loved the service!") String comment,
            Instant createdAt,
            @Schema(description = "The reviewed business's own reply — null until they post one.",
                    example = "Thank you for the kind words!")
            String businessReply,
            @Schema(description = "Only set once businessReply is set.") Instant businessReplyAt) {
        static ReviewResponse from(Review review) {
            return new ReviewResponse(review.getId(), review.getBookingId(), review.getRating(),
                    review.getComment(), review.getCreatedAt(), review.getBusinessReply(),
                    review.getBusinessReplyAt());
        }
    }
}
