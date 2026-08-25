package com.zairo.factory.booking;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BookingDtos {

    private BookingDtos() {
    }

    // totalPrice non-negative mirrors Money's own requireNonNegative check
    // (an uncaught IllegalArgumentException -> undocumented 500 without
    // this — see ServiceOfferingDtos for the same pattern).
    public record CreateBookingRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @NotNull @Schema(description = "Must currently be OPEN — claimed atomically on booking creation, "
                    + "so a race against another customer booking the same slot resolves to a 409 for "
                    + "whoever loses it.", example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            @NotNull @DecimalMin("0") @Schema(example = "25.00") BigDecimal totalPrice) {
    }

    public record BookingResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            BookingStatus status,
            @Schema(example = "25.00") BigDecimal totalPrice,
            @Schema(example = "USD") String currency,
            Instant createdAt) {
        static BookingResponse from(Booking booking) {
            return new BookingResponse(booking.getId(), booking.getUserId(), booking.getServiceId(),
                    booking.getAvailabilitySlotId(), booking.getStatus(), booking.getTotalPrice(),
                    booking.getCurrency(), booking.getCreatedAt());
        }
    }
}
