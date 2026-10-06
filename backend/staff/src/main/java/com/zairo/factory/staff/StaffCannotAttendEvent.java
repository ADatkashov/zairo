package com.zairo.factory.staff;

import java.util.UUID;

/**
 * A staff member told the owner they can't attend an appointment (see {@link StaffPortalService#cannotAttend}).
 * Published once per appointment; notifications emails the business owner.
 */
public record StaffCannotAttendEvent(UUID bookingId, UUID providerId, UUID staffId) {
}
