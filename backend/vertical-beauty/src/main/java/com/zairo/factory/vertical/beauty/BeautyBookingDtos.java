package com.zairo.factory.vertical.beauty;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BeautyBookingDtos {

    private BeautyBookingDtos() {
    }

    public record CreateBeautyBookingRequest(UUID userId, UUID masterId, UUID serviceId, UUID availabilitySlotId,
            BigDecimal totalPrice) {
    }

    public record BeautyBookingResponse(UUID bookingId, UUID masterId, UUID userId, UUID serviceId,
            UUID availabilitySlotId, BookingStatus status, BigDecimal totalPrice, Instant createdAt) {
        static BeautyBookingResponse from(Booking booking, UUID masterId) {
            return new BeautyBookingResponse(booking.getId(), masterId, booking.getUserId(), booking.getServiceId(),
                    booking.getAvailabilitySlotId(), booking.getStatus(), booking.getTotalPrice(),
                    booking.getCreatedAt());
        }
    }
}
