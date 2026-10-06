package com.zairo.factory.staff;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** What the business owner sees and does about staff-related appointments. */
public final class StaffOwnerDtos {

    private StaffOwnerDtos() {
    }

    @Schema(description = "An appointment that needs the owner's decision.")
    public record NeedsAttentionResponse(
            UUID bookingId, String status, Instant startsAt, Instant endsAt, UUID serviceId, String serviceTitle,
            String customerName, String customerPhone, BigDecimal totalPrice, String currency,
            UUID staffId, String staffName,
            @Schema(description = "Why it needs attention: STAFF_CANNOT_ATTEND.") String reason,
            @Schema(description = "The staff member's own words, if any.") String staffNote,
            Instant requestedAt) {
    }

    public record OwnerCancelRequest(
            @Schema(description = "Optional — shown to the customer.", example = "The master is unavailable")
            @Size(max = 500) String reason) {
    }
}
