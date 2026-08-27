package com.zairo.factory.booking;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AvailabilitySlotRepository extends JpaRepository<AvailabilitySlot, UUID> {

    List<AvailabilitySlot> findByProviderId(UUID providerId);

    boolean existsByProviderIdAndStatus(UUID providerId, AvailabilityStatus status);

    /** The soonest OPEN slot, if any — presence/absence also answers "does this provider have open availability". */
    Optional<AvailabilitySlot> findFirstByProviderIdAndStatusOrderByStartsAtAsc(UUID providerId,
            AvailabilityStatus status);

    /**
     * Every existing slot (any status) whose [startsAt, endsAt) window
     * could overlap something in [windowStart, windowEnd) — fetched once
     * for the whole requested date range so RecurringScheduleService can
     * check every candidate slot in memory, not with one query per
     * candidate.
     */
    List<AvailabilitySlot> findByProviderIdAndStartsAtLessThanAndEndsAtGreaterThan(UUID providerId, Instant windowEnd,
            Instant windowStart);
}
