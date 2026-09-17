package com.zairo.factory.booking;

import java.util.UUID;

/**
 * Published the moment {@link BookingService#createBooking} claims a slot
 * (OPEN -&gt; BOOKED) and persists the new booking — success only, no
 * failure variant (see {@link BookingAttemptedEvent} for that). Unlike
 * {@link BookingConfirmedEvent}, this fires at claim time, before payment;
 * it exists specifically so a consumer that only cares about "is this slot
 * still up for grabs" (e.g. {@code smartfill}, closing out a campaign the
 * instant its freed slot is claimed by anyone — a Smart Fill candidate or
 * an unrelated customer who found it via search) doesn't have to wait for
 * payment confirmation, which can lag by however long checkout takes. See
 * ADR-0002 (in-process domain events instead of Kafka).
 */
public record AvailabilitySlotBookedEvent(UUID availabilitySlotId, UUID bookingId, UUID providerId) {
}
