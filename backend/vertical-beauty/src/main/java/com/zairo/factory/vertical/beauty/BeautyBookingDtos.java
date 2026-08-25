package com.zairo.factory.vertical.beauty;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BeautyBookingDtos {

    private BeautyBookingDtos() {
    }

    // totalPrice non-negative mirrors Money's own requireNonNegative check —
    // same grounding as BookingDtos.CreateBookingRequest.
    public record CreateBeautyBookingRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @NotNull @Schema(description = "Must actually offer serviceId — see POST "
                    + "/beauty/masters/{masterId}/services/{serviceId}.",
                    example = "550e8400-e29b-41d4-a716-446655440000") UUID masterId,
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            @NotNull @DecimalMin("0") @Schema(example = "25.00") BigDecimal totalPrice) {
    }

    public record BeautyBookingResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID masterId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            BookingStatus status,
            @Schema(example = "25.00") BigDecimal totalPrice,
            Instant createdAt) {
        static BeautyBookingResponse from(Booking booking, UUID masterId) {
            return new BeautyBookingResponse(booking.getId(), masterId, booking.getUserId(), booking.getServiceId(),
                    booking.getAvailabilitySlotId(), booking.getStatus(), booking.getTotalPrice(),
                    booking.getCreatedAt());
        }
    }
}
