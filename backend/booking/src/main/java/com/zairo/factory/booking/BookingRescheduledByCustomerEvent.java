package com.zairo.factory.booking;

import java.time.Instant;
import java.util.UUID;

/**
 * Published when the customer themselves moves their booking to another time (see
 * {@link BookingService#rescheduleByCustomer}); notifications tells the business. The customer is told by the
 * ordinary {@link BookingMovedEvent} that the move also publishes.
 */
public record BookingRescheduledByCustomerEvent(UUID bookingId, UUID providerId, Instant newStartsAt) {
}
