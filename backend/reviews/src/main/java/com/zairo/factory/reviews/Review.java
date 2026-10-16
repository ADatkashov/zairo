package com.zairo.factory.reviews;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "review")
public class Review {

    @Id
    private UUID id;

    @Column(name = "booking_id", nullable = false, unique = true)
    private UUID bookingId;

    @Column(nullable = false)
    private int rating;

    private String comment;

    /**
     * How the visit was with the person themselves (master, mechanic, ...), when the customer rated them apart
     * from the business; null = one rating only, which then counts for the person as well.
     */
    @Column(name = "worker_rating")
    private Integer workerRating;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** The reviewed business's own reply — set by the provider owner (see ReviewService.replyToReview), never the reviewer. */
    @Column(name = "business_reply")
    private String businessReply;

    @Column(name = "business_reply_at")
    private Instant businessReplyAt;

    protected Review() {
    }

    public Review(UUID id, UUID bookingId, int rating, String comment, Instant createdAt) {
        this(id, bookingId, rating, null, comment, createdAt);
    }

    public Review(UUID id, UUID bookingId, int rating, Integer workerRating, String comment, Instant createdAt) {
        this.id = id;
        this.workerRating = workerRating;
        this.bookingId = bookingId;
        this.rating = rating;
        this.comment = comment;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public int getRating() {
        return rating;
    }

    /** The rating that counts for the person the visit was with: their own if given, else the shared one. */
    public int getRatingForWorker() {
        return workerRating != null ? workerRating : rating;
    }

    public Integer getWorkerRating() {
        return workerRating;
    }

    public String getComment() {
        return comment;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public String getBusinessReply() {
        return businessReply;
    }

    public Instant getBusinessReplyAt() {
        return businessReplyAt;
    }

    /** Overwrites any earlier reply — a business editing its own reply is a normal case, not an error. */
    void addBusinessReply(String reply, Instant now) {
        this.businessReply = reply;
        this.businessReplyAt = now;
    }
}
