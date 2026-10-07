package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Responses of a worker's own cabinet ("my workplaces / my appointments / my rating"). */
public final class WorkerPortalDtos {

    private WorkerPortalDtos() {
    }

    @Schema(description = "One business the signed-in user works at — the cabinet's business switcher.")
    public record WorkerMembershipResponse(
            @Schema(description = "The worker id at this business (whichever directory they were added through).")
            UUID staffId,
            WorkerKind kind, UUID providerId, String providerName, String displayName, String photoUrl,
            boolean active,
            @Schema(description = "Upcoming, paid appointments the worker hasn't accepted yet.") int pendingCount,
            @Schema(description = "Average rating of reviews on this worker's appointments; null if none.")
            Double averageRating,
            long reviewCount) {
    }

    public record WorkerAppointmentResponse(
            UUID bookingId, String status, Instant startsAt, Instant endsAt, UUID serviceId, String serviceTitle,
            String customerName, String customerPhone, BigDecimal totalPrice, String currency,
            BigDecimal paidAmount, String cancellationReason,
            @Schema(description = "When the worker accepted it; null while not accepted.") Instant staffConfirmedAt,
            @Schema(description = "When the worker told the owner they can't attend; null otherwise.")
            Instant staffDeclinedAt,
            boolean canAccept, boolean canDecline, boolean canComplete, boolean canMarkNoShow) {
    }

    public record CannotAttendRequest(
            @Schema(description = "Optional — why the worker can't attend.", example = "Sick leave")
            @Size(max = 500) String reason) {
    }

    public record WorkerReviewResponse(
            UUID reviewId, UUID bookingId, String customerName, int rating, String comment, Instant createdAt,
            String businessReply, Instant businessReplyAt) {
    }

    public record WorkerRatingResponse(
            Double averageRating, long reviewCount,
            @Schema(description = "Review counts for 1..5 stars, index 0 = one star.") List<Long> distribution,
            List<WorkerReviewResponse> reviews) {
    }
}
