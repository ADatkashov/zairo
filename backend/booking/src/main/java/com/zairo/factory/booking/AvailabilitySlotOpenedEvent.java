package com.zairo.factory.booking;

import java.time.Instant;
import java.util.UUID;

/**
 * Published after a booked slot goes back to OPEN — its booking was cancelled, expired unpaid, or moved to another
 * time. {@code releasedByUserId} is the customer who held it (they already know, and must not be told it "opened").
 * Consumer so far: waitlist, which tells the customers waiting for this business.
 */
public record AvailabilitySlotOpenedEvent(UUID slotId, UUID providerId, Instant startsAt, Instant endsAt,
        UUID releasedByUserId) {
}
