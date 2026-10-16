package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/** What a customer sees of a worker: the "best masters" rail and a worker's public page. */
public final class WorkerDirectoryDtos {

    private WorkerDirectoryDtos() {
    }

    public record TopWorkerResponse(
            UUID id,
            @Schema(description = "Which directory the worker lives in; MASTER has a photo portfolio.")
            WorkerKind kind,
            UUID providerId,
            @Schema(example = "Aigerim Beauty Studio") String providerName,
            @Schema(example = "Aigerim") String displayName,
            String photoUrl,
            @Schema(description = "Mean of the 1-5 ratings on this worker's bookings, one decimal.", example = "4.8")
            double averageRating,
            @Schema(example = "17") long reviewCount) {
        static TopWorkerResponse from(WorkerCatalog.Ranked ranked) {
            Worker w = ranked.worker();
            return new TopWorkerResponse(w.id(), w.kind(), w.providerId(), ranked.providerName(), w.displayName(),
                    w.photoUrl(), Math.round(ranked.averageRating() * 10) / 10.0, ranked.reviewCount());
        }
    }

    /** One person on a customer's "my masters" list; no rating yet = null average, zero reviews. */
    public record FavoriteWorkerResponse(
            UUID id,
            WorkerKind kind,
            UUID providerId,
            String providerName,
            String displayName,
            String photoUrl,
            @Schema(description = "Null until somebody has reviewed them.", example = "4.8") Double averageRating,
            long reviewCount) {
    }

    /** Who a booking is with, for the customer who made it. */
    public record BookingWorkerResponse(UUID id, WorkerKind kind, String displayName, String photoUrl) {
    }

    public record WorkerServiceResponse(UUID id, String title, int durationMinutes, BigDecimal price,
            String currency) {
    }

    public record WorkerReviewResponse(int rating, String comment, java.time.Instant createdAt,
            String businessReply) {
    }

    public record WorkerProfileResponse(
            UUID id,
            WorkerKind kind,
            UUID providerId,
            String providerName,
            String displayName,
            String photoUrl,
            @Schema(description = "The worker's own 'about me'; null when they wrote none.") String bio,
            @Schema(description = "Null until the worker has a review.") Double averageRating,
            long reviewCount,
            @Schema(description = "The newest few reviews, no reviewer names.") List<WorkerReviewResponse> reviews,
            List<WorkerServiceResponse> services) {
    }
}
