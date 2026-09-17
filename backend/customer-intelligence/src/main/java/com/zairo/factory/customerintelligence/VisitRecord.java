package com.zairo.factory.customerintelligence;

import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * One booking, joined with its slot's own fields ({@code providerId}/
 * {@code employeeId}/{@code startsAt}) since {@code Booking} itself carries
 * neither -- see {@code Booking}'s own doc comment on the bounded-context
 * boundary. The shape every calculator in this module works from, built by
 * {@link BookingHistoryReader}.
 */
record VisitRecord(
        UUID bookingId,
        UUID providerId,
        UUID serviceId,
        UUID employeeId,
        BookingStatus status,
        Instant startsAt,
        Instant createdAt,
        BigDecimal totalPrice,
        String currency) {
}
