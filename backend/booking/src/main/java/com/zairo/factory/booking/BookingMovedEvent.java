package com.zairo.factory.booking;

import java.time.Instant;
import java.util.UUID;

/**
 * Published when an active booking is moved to a slot with a different time (see
 * {@link BookingService#moveToSlotAuthorized}); notifications tells the customer. Not published when only the
 * person changes at the same time — that has its own event in {@code workforce}.
 */
public record BookingMovedEvent(UUID bookingId, UUID userId, UUID providerId, Instant newStartsAt) {
}
