package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** What the business owner sees and does about worker-related appointments. */
public final class WorkerOwnerDtos {

    private WorkerOwnerDtos() {
    }

    @Schema(description = "An appointment that needs the owner's decision.")
    public record NeedsAttentionResponse(
            UUID bookingId, String status, Instant startsAt, Instant endsAt, UUID serviceId, String serviceTitle,
            String customerName, String customerPhone, BigDecimal totalPrice, String currency,
            UUID workerId, WorkerKind workerKind, String workerName,
            @Schema(description = "Why it needs attention: WORKER_CANNOT_ATTEND.") String reason,
            @Schema(description = "The worker's own words, if any.") String workerNote,
            Instant requestedAt) {
    }

    public record OwnerCancelRequest(
            @Schema(description = "Optional — shown to the customer.", example = "The master is unavailable")
            @Size(max = 500) String reason) {
    }
}
