package com.zairo.factory.workforce;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * An appointment now has a different person (same time): the customer is told who will serve them.
 * {@code newPrice} is set when the replacement charges less, so the customer's price dropped to it (and what they
 * had already paid above it goes back to them); null when the price is unchanged.
 */
public record WorkerReassignedEvent(UUID bookingId, UUID userId, UUID providerId, String fromName, String toName,
        boolean customerDidntMind, BigDecimal newPrice) {
}
