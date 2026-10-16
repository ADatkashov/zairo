package com.zairo.factory.booking;

import java.util.UUID;

/**
 * Published after a booking is cancelled by its own customer — see
 * ADR-0002 (in-process domain events instead of Kafka). Mirrors {@link
 * BookingConfirmedEvent}. Consumers so far: payments (issues a refund if
 * the booking had a successful payment) and notifications (tells the
 * customer/provider the booking was cancelled) — neither needs booking to
 * depend on them. {@code reason} is what the canceller said, null when nothing.
 */
public record BookingCancelledEvent(UUID bookingId, UUID userId, UUID providerId, String reason) {
}
