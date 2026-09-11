package com.zairo.factory.booking;

import java.util.UUID;

/**
 * Published after a provider owner marks a CONFIRMED booking COMPLETED —
 * see ADR-0002 (in-process domain events instead of Kafka). No listener
 * consumes this yet; it exists as the event-foundation hook a future
 * rebooking-analysis strategy (see {@code revenueengine}'s package-info —
 * "was this customer due for another visit soon") would trigger from,
 * same "publish now, consume later" precedent as {@link BookingAttemptedEvent}.
 */
public record BookingCompletedEvent(UUID bookingId, UUID userId, UUID providerId, UUID serviceId) {
}
