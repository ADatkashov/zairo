package com.zairo.factory.workforce;

import java.time.Instant;
import java.util.UUID;

/**
 * An upcoming appointment hasn't been accepted by its worker yet (see {@link WorkerUnacceptedWarningService}).
 * Published once per appointment; notifications warns the business owner while there is still time to react.
 */
public record WorkerNotAcceptedEvent(UUID bookingId, UUID providerId, String workerName, Instant startsAt) {
}
