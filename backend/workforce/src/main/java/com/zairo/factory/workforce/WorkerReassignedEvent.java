package com.zairo.factory.workforce;

import java.util.UUID;

/** An appointment now has a different person (same time): the customer is told who will serve them. */
public record WorkerReassignedEvent(UUID bookingId, UUID userId, UUID providerId, String fromName, String toName,
        boolean customerDidntMind) {
}
