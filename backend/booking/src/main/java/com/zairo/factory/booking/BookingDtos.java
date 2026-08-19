package com.zairo.factory.booking;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BookingDtos {

    private BookingDtos() {
    }

    public record CreateBookingRequest(UUID userId, UUID serviceId, UUID availabilitySlotId,
            BigDecimal totalPrice) {
    }

    public record BookingResponse(UUID id, UUID userId, UUID serviceId, UUID availabilitySlotId,
            BookingStatus status, BigDecimal totalPrice, Instant createdAt) {
        static BookingResponse from(Booking booking) {
            return new BookingResponse(booking.getId(), booking.getUserId(), booking.getServiceId(),
                    booking.getAvailabilitySlotId(), booking.getStatus(), booking.getTotalPrice(),
                    booking.getCreatedAt());
        }
    }
}
