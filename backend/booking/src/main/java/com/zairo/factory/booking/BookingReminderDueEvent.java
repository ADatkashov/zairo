package com.zairo.factory.booking;

import java.util.UUID;

/**
 * Published once, per booking, roughly an hour before its slot starts —
 * see ADR-0002 (in-process domain events instead of Kafka). {@link
 * BookingReminderJob} is the only publisher, guarded by {@code
 * Booking.reminderSentAt} so this never fires twice for the same booking
 * regardless of how often the job runs.
 */
public record BookingReminderDueEvent(UUID bookingId, UUID userId) {
}
