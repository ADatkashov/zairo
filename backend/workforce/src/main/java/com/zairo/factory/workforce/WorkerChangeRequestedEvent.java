package com.zairo.factory.workforce;

import java.util.UUID;

/** The owner asked the customer to decide what happens to an appointment whose person can't make it. */
public record WorkerChangeRequestedEvent(UUID bookingId, UUID userId, UUID providerId, String workerName) {
}
