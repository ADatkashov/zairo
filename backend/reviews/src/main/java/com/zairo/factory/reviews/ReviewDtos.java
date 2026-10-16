package com.zairo.factory.reviews;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ReviewDtos {

    private ReviewDtos() {
    }

    // 1-5 mirrors the exact range ReviewService.createReview already
    // enforces (as a proper 400) — duplicated here only so springdoc/Swagger
    // can show the bound in the schema and reject it a step earlier.
    public record CreateReviewRequest(
            @Min(1) @Max(5) @Schema(example = "5") int rating,
            @Schema(description = "Optional.", example = "Loved the service!") String comment,
            @Min(1) @Max(5) @Schema(description = "Optional second rating for the person the visit was with "
                    + "(master, mechanic, ...), apart from the business. Omit to rate both with `rating`.",
                    example = "5") Integer workerRating) {
        public CreateReviewRequest(int rating, String comment) {
            this(rating, comment, null);
        }
    }

    public record ReportReviewRequest(
            @NotBlank @Size(max = 1000) @Schema(description = "Why the review should be looked at.",
                    example = "Abusive language") String reason) {
    }

    public record ModerationDecisionRequest(
            @Size(max = 1000) @Schema(description = "Optional note, kept in the audit log (and shown as the hidden "
                    + "reason).", example = "Contains personal data") String reason) {
    }

    /** One row of the platform's moderation queue. */
    public record ModerationReviewResponse(
            UUID id, UUID bookingId, UUID providerId, String providerName, int rating, String comment,
            Instant createdAt, String businessReply, String reportReason, Instant reportedAt,
            @Schema(description = "OPEN (waiting for a decision), HIDDEN (kept out of every rating) or DISMISSED "
                    + "(looked at, stays).") String status,
            Instant hiddenAt, String hiddenReason,
            @Schema(description = "When the platform decided (hid it, or looked and kept it); null while OPEN.")
            Instant decidedAt) {
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
            @Schema(description = "Only set once businessReply is set.") Instant businessReplyAt,
            @Schema(description = "The separate rating of the person the visit was with; null = `rating` counts "
                    + "for them too.", example = "5") Integer workerRating) {
        static ReviewResponse from(Review review) {
            return new ReviewResponse(review.getId(), review.getBookingId(), review.getRating(),
                    review.getComment(), review.getCreatedAt(), review.getBusinessReply(),
                    review.getBusinessReplyAt(), review.getWorkerRating());
        }
    }

    /** One row of the owner-facing reviews list — {@link ReviewResponse} plus the reviewer's name. */
    public record ProviderReviewResponse(
            UUID id, UUID bookingId,
            @Schema(description = "The reviewing customer's display name.", example = "Aisha K.") String customerName,
            int rating, String comment, Instant createdAt,
            String businessReply, Instant businessReplyAt,
            @Schema(description = "Moderation state: null = never reported; OPEN = reported, waiting for the "
                    + "platform; HIDDEN = kept out of every rating; DISMISSED = reported, the platform kept it.")
            String moderationStatus) {
    }

    /**
     * One row of the public reviews list. Deliberately has no bookingId or
     * userId, and the author is abbreviated ("Aisha K.") — anyone can read
     * this, so it must not identify a customer beyond a first name.
     */
    public record PublicReviewResponse(
            UUID id,
            @Schema(description = "First name plus last initial; never an email or phone.", example = "Aisha K.")
            String authorName,
            @Schema(example = "5") int rating,
            @Schema(example = "Loved the service!") String comment,
            Instant createdAt,
            @Schema(description = "The business's reply — null until they post one.") String businessReply,
            Instant businessReplyAt) {
    }

    public record ReviewSummaryResponse(
            @Schema(description = "Mean rating rounded to one decimal; null when there are no reviews.",
                    example = "4.8") Double average,
            @Schema(example = "128") long total,
            @Schema(description = "Review count for stars 1..5, always five entries (index 0 = 1 star).",
                    example = "[0, 1, 3, 20, 104]") List<Long> distribution) {
    }
}
