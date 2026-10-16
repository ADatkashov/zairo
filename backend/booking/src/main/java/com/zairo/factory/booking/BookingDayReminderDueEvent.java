package com.zairo.factory.booking;

import java.time.Instant;
import java.util.UUID;

/**
 * Published once per booking, when its visit is about a day away (and it was booked at least a day ahead). Guarded by
 * {@code Booking.dayReminderSentAt}; {@link BookingReminderJob} is the only publisher.
 */
public record BookingDayReminderDueEvent(UUID bookingId, UUID userId, Instant startsAt) {
}
