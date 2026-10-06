package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** What the business owner sees and does about worker-related appointments. */
public final class WorkerOwnerDtos {

    private WorkerOwnerDtos() {
    }

    @Schema(description = "A colleague who could take the appointment.")
    public record ReplacementResponse(
            UUID workerId, String name,
            @Schema(description = "True when the appointment falls within their usual working hours; false means "
                    + "it would be outside them (the owner may still choose them).") boolean atWorkingTime) {
    }

    @Schema(description = "An appointment that needs the owner's decision.")
    public record NeedsAttentionResponse(
            UUID bookingId, String status, Instant startsAt, Instant endsAt, UUID serviceId, String serviceTitle,
            String customerName, String customerPhone, BigDecimal totalPrice, String currency,
            UUID workerId, WorkerKind workerKind, String workerName,
            @Schema(description = "Why it needs attention: WORKER_CANNOT_ATTEND (they said so), WORKER_UNAVAILABLE "
                    + "(they are off then), WORKER_INACTIVE (they no longer work here) or WORKER_NOT_ACCEPTED (the visit is "
                    + "close and they haven't accepted it).") String reason,
            @Schema(description = "The worker's own words, if any.") String workerNote,
            Instant requestedAt,
            @Schema(description = "SPECIFIC (the customer chose this person) or ANY.") String preference,
            @Schema(description = "When the customer was asked to decide; null if not asked yet.")
            Instant customerAskedAt,
            @Schema(description = "Colleagues who could take it, those working at that time first.")
            List<ReplacementResponse> replacements) {
    }

    public record OwnerCancelRequest(
            @Schema(description = "Optional — shown to the customer.", example = "The master is unavailable")
            @Size(max = 500) String reason) {
    }

    public record ReassignRequest(@NotNull @Schema(description = "The colleague who takes the appointment.") UUID workerId) {
    }
}
