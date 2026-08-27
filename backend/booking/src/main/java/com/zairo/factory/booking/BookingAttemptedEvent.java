package com.zairo.factory.booking;

import java.util.UUID;

/**
 * Published on every {@code createBooking} call, success or failure — no
 * listener consumes this yet (see the discovery ADR's analytics-hooks
 * section). {@code succeeded=true} always accompanies a
 * {@link BookingConfirmedEvent} published in the same call; the point of
 * this event is capturing the failed attempts {@code BookingConfirmedEvent}
 * alone can't see, for a future conversion-rate metric ("attempts" vs.
 * "confirmed").
 */
public record BookingAttemptedEvent(UUID userId, UUID serviceId, UUID providerId, boolean succeeded,
        String failureReason) {
}
