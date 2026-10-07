package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** What a customer sees and answers when their person can't make it and the owner asked them to decide. */
public final class WorkerChangeDtos {

    private WorkerChangeDtos() {
    }

    public enum Choice {
        /** Take a colleague at the same time. */
        REPLACE,
        /** Keep the same person, at another time. */
        MOVE,
        /** Cancel, with a refund. */
        CANCEL
    }

    public record ReplacementOption(UUID workerId, String name) {
    }

    public record TimeOption(UUID slotId, Instant startsAt, Instant endsAt) {
    }

    @Schema(description = "An appointment whose person can't make it; the customer decides what happens.")
    public record ChangeRequestResponse(
            UUID bookingId, UUID providerId, String providerName, String serviceTitle, Instant startsAt,
            Instant endsAt, String workerName, String reason, Instant askedAt,
            @Schema(description = "Colleagues free at the same time.") List<ReplacementOption> replacements,
            @Schema(description = "Other times with the same person (empty if they're no longer available).")
            List<TimeOption> otherTimes) {
    }

    public record ChangeResponseRequest(
            @NotNull Choice choice,
            @Schema(description = "Required for REPLACE.") UUID workerId,
            @Schema(description = "Required for MOVE.") UUID slotId) {
    }
}
