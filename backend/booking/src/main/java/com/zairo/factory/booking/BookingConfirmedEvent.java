package com.zairo.factory.booking;

import java.util.UUID;

/**
 * Published after a booking commits successfully — see ADR-0002 (in-process
 * domain events instead of Kafka). Other modules (e.g. notifications, once
 * it has something to send) listen for this without booking depending on
 * them.
 */
public record BookingConfirmedEvent(UUID bookingId, UUID userId, UUID providerId) {
}
