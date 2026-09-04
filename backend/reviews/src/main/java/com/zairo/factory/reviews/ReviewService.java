package com.zairo.factory.reviews;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.ProviderOwnership;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderOwnership providerOwnership;

    public ReviewService(ReviewRepository reviewRepository, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ProviderOwnership providerOwnership) {
        this.reviewRepository = reviewRepository;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
    }

    @Transactional
    public Review createReview(UUID bookingId, UUID callerId, int rating, String comment) {
        if (rating < 1 || rating > 5) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "rating must be between 1 and 5: " + rating);
        }

        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        if (!booking.getUserId().equals(callerId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this booking: " + bookingId);
        }

        if (booking.getStatus() != BookingStatus.COMPLETED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Booking is not completed yet: " + bookingId
                    + " (status=" + booking.getStatus() + ")");
        }

        if (reviewRepository.existsByBookingId(bookingId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Booking already has a review: " + bookingId);
        }

        Review review = new Review(UUID.randomUUID(), bookingId, rating, comment, Instant.now());
        return reviewRepository.save(review);
    }

    /**
     * Only the reviewed booking's provider owner may reply — resolved the
     * same way {@code BookingService.markNoShow} resolves it (booking ->
     * availability slot -> provider), since a review has no direct
     * providerId of its own (same bounded-context boundary reasoning as
     * booking's own doc comment).
     */
    @Transactional
    public Review replyToReview(UUID reviewId, UUID callerId, String reply) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Review not found: "
                        + reviewId));

        Booking booking = bookingRepository.findById(review.getBookingId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + review.getBookingId()));
        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + booking.getAvailabilitySlotId()));
        providerOwnership.requireOwner(slot.getProviderId(), callerId);

        review.addBusinessReply(reply, Instant.now());
        return reviewRepository.save(review);
    }
}
