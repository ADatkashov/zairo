package com.zairo.factory.vertical.auto;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class AutoBookingDtos {

    private AutoBookingDtos() {
    }

    // totalPrice non-negative mirrors Money's own requireNonNegative check —
    // same grounding as BookingDtos.CreateBookingRequest.
    public record CreateAutoBookingRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @NotNull @Schema(description = "Must actually offer serviceId — see POST "
                    + "/auto/mechanics/{mechanicId}/services/{serviceId}.",
                    example = "550e8400-e29b-41d4-a716-446655440000") UUID mechanicId,
            @NotNull @Schema(description = "Must belong to userId — see POST /vehicles.",
                    example = "550e8400-e29b-41d4-a716-446655440000") UUID vehicleId,
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            @NotNull @DecimalMin("0") @Schema(example = "35.00") BigDecimal totalPrice) {
    }

    public record AutoBookingResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID mechanicId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID vehicleId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            BookingStatus status,
            @Schema(example = "35.00") BigDecimal totalPrice,
            Instant createdAt) {
        static AutoBookingResponse from(Booking booking, UUID mechanicId, UUID vehicleId) {
            return new AutoBookingResponse(booking.getId(), mechanicId, vehicleId, booking.getUserId(),
                    booking.getServiceId(), booking.getAvailabilitySlotId(), booking.getStatus(),
                    booking.getTotalPrice(), booking.getCreatedAt());
        }
    }
}
