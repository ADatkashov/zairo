package com.zairo.factory.staff;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Responses of the staff member's own cabinet ("my workplaces / my appointments / my rating"). */
public final class StaffPortalDtos {

    private StaffPortalDtos() {
    }

    @Schema(description = "One business the signed-in user works at — the cabinet's business switcher.")
    public record StaffMembershipResponse(
            UUID staffId, UUID providerId, String providerName, String displayName, String photoUrl,
            boolean active,
            @Schema(description = "Upcoming, paid appointments the staff member hasn't accepted yet.")
            int pendingCount,
            @Schema(description = "Average rating of reviews on this staff member's appointments; null if none.")
            Double averageRating,
            long reviewCount) {
    }

    public record StaffAppointmentResponse(
            UUID bookingId, String status, Instant startsAt, Instant endsAt, UUID serviceId, String serviceTitle,
            String customerName, String customerPhone, BigDecimal totalPrice, String currency,
            BigDecimal paidAmount, String cancellationReason,
            @Schema(description = "When the staff member accepted it; null while not accepted.")
            Instant staffConfirmedAt,
            boolean canAccept, boolean canCancel, boolean canComplete, boolean canMarkNoShow) {
    }

    public record DeclineAppointmentRequest(
            @Schema(description = "Optional — why the staff member cancels.", example = "Sick leave") String reason) {
    }

    public record StaffReviewResponse(
            UUID reviewId, UUID bookingId, String customerName, int rating, String comment, Instant createdAt,
            String businessReply, Instant businessReplyAt) {
    }

    public record StaffRatingResponse(
            Double averageRating, long reviewCount,
            @Schema(description = "Review counts for 1..5 stars, index 0 = one star.") List<Long> distribution,
            List<StaffReviewResponse> reviews) {
    }
}
