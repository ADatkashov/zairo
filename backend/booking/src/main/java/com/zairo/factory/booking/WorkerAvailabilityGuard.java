package com.zairo.factory.booking;

import java.util.UUID;

/**
 * A hook the worker-specific booking flows (beauty master, auto mechanic, cleaner, generic staff) call right before
 * they claim a slot for a named worker, so one rule can veto the booking without booking depending on whoever
 * implements it. Implemented by {@code workforce}: a person can't be sold twice for the same time, can't be booked
 * while off, and can't be booked as a specific person when the business only takes "any master".
 *
 * <p>Implementations throw {@link SlotNotAvailableException} (HTTP 409) to refuse.
 */
public interface WorkerAvailabilityGuard {

    /**
     * @param workerId       the worker the customer is booking (any of the four directories)
     * @param slot           the slot about to be claimed
     * @param customerUserId the customer
     */
    void requireBookable(UUID workerId, AvailabilitySlot slot, UUID customerUserId);
}
