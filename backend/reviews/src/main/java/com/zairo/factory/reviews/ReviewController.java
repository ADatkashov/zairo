package com.zairo.factory.reviews;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
import com.zairo.factory.reviews.ReviewDtos.ProviderReviewResponse;
import com.zairo.factory.reviews.ReviewDtos.PublicReviewResponse;
import com.zairo.factory.reviews.ReviewDtos.ReplyToReviewRequest;
import com.zairo.factory.reviews.ReviewDtos.ReportReviewRequest;
import com.zairo.factory.reviews.ReviewDtos.ReviewResponse;
import com.zairo.factory.reviews.ReviewDtos.ReviewSummaryResponse;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Reviews")
public class ReviewController {

    private final ReviewService reviewService;
    private final ReviewRepository reviewRepository;
    private final UserRepository userRepository;

    public ReviewController(ReviewService reviewService, ReviewRepository reviewRepository,
            UserRepository userRepository) {
        this.reviewService = reviewService;
        this.reviewRepository = reviewRepository;
        this.userRepository = userRepository;
    }

    @Operation(summary = "Leave a review for a booking", description = """
            No review without a verified visit: the booking must be COMPLETED, and can only be reviewed \
            once. Customer-only — the caller must be the booking's own user.

            **Workflow**: `Create booking -> Mark complete -> Leave a review` — the booking has to reach \
            COMPLETED first (see POST /bookings/{id}/complete).""")
    @ApiResponse(responseCode = "201", description = "Review created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller doesn't own this booking.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The booking doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The booking isn't COMPLETED yet, or already has a "
            + "review.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/bookings/{bookingId}/reviews")
    @ResponseStatus(HttpStatus.CREATED)
    public ReviewResponse create(@Parameter(description = "The booking's id.") @PathVariable UUID bookingId,
            @Valid @RequestBody CreateReviewRequest request) {
        UUID callerId = CurrentUser.requireUserId();
        Review review = reviewService.createReview(bookingId, callerId, request.rating(), request.workerRating(),
                request.comment());
        return ReviewResponse.from(review);
    }

    @Operation(summary = "Get a booking's review")
    @ApiResponse(responseCode = "200", description = "The review")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "This booking has no review yet.")
    @GetMapping("/api/v1/bookings/{bookingId}/reviews")
    public ReviewResponse getByBooking(@Parameter(description = "The booking's id.") @PathVariable UUID bookingId) {
        return reviewRepository.findByBookingId(bookingId).map(ReviewResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "No review for booking: " + bookingId));
    }

    @Operation(summary = "Reply to a review", description = """
            Only the reviewed booking's provider owner may reply. Posting again overwrites the earlier \
            reply — editing your own reply is a normal case, not an error.""")
    @ApiResponse(responseCode = "200", description = "Reply saved")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller doesn't own this review's provider.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/reviews/{reviewId}/reply")
    public ReviewResponse reply(@Parameter(description = "The review's id.") @PathVariable UUID reviewId,
            @Valid @RequestBody ReplyToReviewRequest request) {
        UUID callerId = CurrentUser.requireUserId();
        Review review = reviewService.replyToReview(reviewId, callerId, request.reply());
        return ReviewResponse.from(review);
    }

    @Operation(summary = "Report a review to the platform", description = """
            Only the reviewed booking's provider owner. One report per review: a second one (or one on a review the \
            platform already hid) is 409. The platform then hides the review or keeps it.""")
    @ApiResponse(responseCode = "204", description = "Reported")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller doesn't own this review's provider.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "Already reported.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/reviews/{reviewId}/report")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void report(@Parameter(description = "The review's id.") @PathVariable UUID reviewId,
            @Valid @RequestBody ReportReviewRequest request) {
        reviewService.reportReview(reviewId, CurrentUser.requireUserId(), request.reason());
    }

    @Operation(summary = "List a provider's reviews", description = """
            Owner-only, newest first. Powers the Business Admin reviews screen — each row carries the \
            reviewer's display name so the owner never sees a bare customer id.""")
    @ApiResponse(responseCode = "200", description = "Page of reviews")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller doesn't own this provider.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/reviews")
    public Page<ProviderReviewResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId, Pageable pageable) {
        UUID callerId = CurrentUser.requireUserId();
        Page<ReviewRepository.OwnerReviewRow> rows = reviewService.listByProvider(providerId, callerId, pageable);

        Map<UUID, String> namesByUserId = userRepository
                .findAllById(rows.map(ReviewRepository.ProviderReviewRow::getUserId).toList()).stream()
                .collect(Collectors.toMap(User::getId, User::getDisplayName));

        return rows.map(row -> new ProviderReviewResponse(row.getId(), row.getBookingId(),
                namesByUserId.getOrDefault(row.getUserId(), "Customer"), row.getRating(), row.getComment(),
                row.getCreatedAt(), row.getBusinessReply(), row.getBusinessReplyAt(), moderationStatus(row)));
    }

    private static String moderationStatus(ReviewRepository.OwnerReviewRow row) {
        if (row.getHiddenAt() != null) {
            return "HIDDEN";
        }
        if (row.getReportedAt() == null) {
            return null;
        }
        return row.getReportResolvedAt() == null ? "OPEN" : "DISMISSED";
    }

    @Operation(summary = "List a provider's public reviews", description = """
            Public (no token), newest first by default (`sort=highest|lowest` to reorder; `rating=1..5` and \
            `withComment=true` to filter), page size capped at 50. Authors are abbreviated to first name \
            plus last initial; no booking or user ids are exposed. Includes the business's reply when there \
            is one.""")
    @ApiResponse(responseCode = "200", description = "Page of reviews")
    @GetMapping("/api/v1/providers/{providerId}/reviews/public")
    public Page<PublicReviewResponse> listPublic(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Only this star rating (1-5).") @RequestParam(required = false) Integer rating,
            @Parameter(description = "Only reviews that have written text.")
            @RequestParam(defaultValue = "false") boolean withComment,
            @Parameter(description = "newest (default), highest or lowest.")
            @RequestParam(required = false) String sort, Pageable pageable) {
        Pageable capped = PageRequest.of(pageable.getPageNumber(), Math.min(pageable.getPageSize(), 50));
        Page<ReviewRepository.ProviderReviewRow> rows = reviewService.listPublic(providerId, rating, withComment, sort, capped);

        Map<UUID, String> namesByUserId = userRepository
                .findAllById(rows.map(ReviewRepository.ProviderReviewRow::getUserId).toList()).stream()
                .collect(Collectors.toMap(User::getId, u -> ReviewerNames.abbreviate(u.getDisplayName())));

        return rows.map(row -> new PublicReviewResponse(row.getId(),
                namesByUserId.getOrDefault(row.getUserId(), ReviewerNames.FALLBACK), row.getRating(),
                row.getComment(), row.getCreatedAt(), row.getBusinessReply(), row.getBusinessReplyAt()));
    }

    @Operation(summary = "A provider's rating summary", description = """
            Public (no token). Average (one decimal), total count and the count per star 1..5 -- the data \
            behind the "4.8 from 128 reviews" header and distribution bars.""")
    @ApiResponse(responseCode = "200", description = "The summary; total 0 and average null when unreviewed")
    @GetMapping("/api/v1/providers/{providerId}/reviews/summary")
    public ReviewSummaryResponse summary(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return reviewService.summarize(providerId);
    }
}
