package com.zairo.factory.reviews;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
import com.zairo.factory.reviews.ReviewDtos.ReplyToReviewRequest;
import com.zairo.factory.reviews.ReviewDtos.ReviewResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Reviews")
public class ReviewController {

    private final ReviewService reviewService;
    private final ReviewRepository reviewRepository;

    public ReviewController(ReviewService reviewService, ReviewRepository reviewRepository) {
        this.reviewService = reviewService;
        this.reviewRepository = reviewRepository;
    }

    @Operation(summary = "Leave a review for a booking", description = """
            No review without a verified visit: the booking must be COMPLETED, and can only be reviewed \
            once. No authentication is required by this endpoint itself.

            **Workflow**: `Create booking -> Mark complete -> Leave a review` — the booking has to reach \
            COMPLETED first (see POST /bookings/{id}/complete).""")
    @ApiResponse(responseCode = "201", description = "Review created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The booking doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The booking isn't COMPLETED yet, or already has a "
            + "review.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/bookings/{bookingId}/reviews")
    @ResponseStatus(HttpStatus.CREATED)
    public ReviewResponse create(@Parameter(description = "The booking's id.") @PathVariable UUID bookingId,
            @Valid @RequestBody CreateReviewRequest request) {
        Review review = reviewService.createReview(bookingId, request.rating(), request.comment());
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
            @Valid @RequestBody ReplyToReviewRequest request, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        Review review = reviewService.replyToReview(reviewId, callerId, request.reply());
        return ReviewResponse.from(review);
    }
}
