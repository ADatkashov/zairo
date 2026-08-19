package com.zairo.factory.reviews;

import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
import com.zairo.factory.reviews.ReviewDtos.ReviewResponse;
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
public class ReviewController {

    private final ReviewService reviewService;
    private final ReviewRepository reviewRepository;

    public ReviewController(ReviewService reviewService, ReviewRepository reviewRepository) {
        this.reviewService = reviewService;
        this.reviewRepository = reviewRepository;
    }

    @PostMapping("/api/v1/bookings/{bookingId}/reviews")
    @ResponseStatus(HttpStatus.CREATED)
    public ReviewResponse create(@PathVariable UUID bookingId, @RequestBody CreateReviewRequest request) {
        Review review = reviewService.createReview(bookingId, request.rating(), request.comment());
        return ReviewResponse.from(review);
    }

    @GetMapping("/api/v1/bookings/{bookingId}/reviews")
    public ReviewResponse getByBooking(@PathVariable UUID bookingId) {
        return reviewRepository.findByBookingId(bookingId).map(ReviewResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "No review for booking: " + bookingId));
    }
}
