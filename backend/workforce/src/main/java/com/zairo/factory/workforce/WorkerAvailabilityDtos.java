package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** What a customer sees when picking a person or "any master". */
public final class WorkerAvailabilityDtos {

    private WorkerAvailabilityDtos() {
    }

    @Schema(description = "A time the customer can book, with the person who would serve them.")
    public record AnySlotResponse(
            UUID slotId, Instant startsAt, Instant endsAt, UUID workerId, WorkerKind workerKind) {
    }

    public record BookAnyRequest(
            @NotNull UUID userId, @NotNull UUID serviceId,
            @NotNull @Schema(description = "The start time picked from GET .../availability/any.") Instant startsAt,
            @Schema(description = "Only for auto businesses: the customer's vehicle.") UUID vehicleId) {
    }

    public record BookAnyResponse(
            UUID bookingId, UUID workerId, WorkerKind workerKind, UUID userId, UUID serviceId,
            UUID availabilitySlotId, String status, BigDecimal totalPrice, String currency, Instant createdAt) {
    }
}
