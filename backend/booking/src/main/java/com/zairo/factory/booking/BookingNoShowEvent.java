package com.zairo.factory.booking;

import java.util.UUID;

/**
 * Published after a provider owner marks a CONFIRMED booking as a no-show —
 * see ADR-0002. No listener consumes this yet; it exists as the
 * event-foundation hook a future no-show-risk strategy (see {@code
 * revenueengine}'s package-info) would use to learn from an actual no-show,
 * same "publish now, consume later" precedent as {@link BookingAttemptedEvent}.
 */
public record BookingNoShowEvent(UUID bookingId, UUID userId, UUID providerId) {
}
