package com.zairo.factory.workforce;

import java.time.Instant;
import java.util.UUID;

/** A worker closed their own availability (e.g. reported sick); the owner is told, with how many bookings it touches. */
public record WorkerUnavailableEvent(UUID workerId, UUID providerId, String workerName, Instant from, Instant to,
        int affectedAppointments) {
}
