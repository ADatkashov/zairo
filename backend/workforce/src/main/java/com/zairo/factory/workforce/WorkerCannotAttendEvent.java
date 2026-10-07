package com.zairo.factory.workforce;

import java.util.UUID;

/**
 * A worker told the owner they can't attend an appointment (see {@link WorkerPortalService#cannotAttend}).
 * Published once per appointment; notifications emails the business owner.
 */
public record WorkerCannotAttendEvent(UUID bookingId, UUID providerId, UUID workerId) {
}
