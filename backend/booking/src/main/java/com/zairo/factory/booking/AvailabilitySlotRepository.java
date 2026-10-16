package com.zairo.factory.booking;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AvailabilitySlotRepository extends JpaRepository<AvailabilitySlot, UUID> {

    List<AvailabilitySlot> findByProviderId(UUID providerId);

    List<AvailabilitySlot> findByProviderIdAndEmployeeId(UUID providerId, UUID employeeId);

    /** A worker's own slots of one status that start after the given moment. */
    List<AvailabilitySlot> findByProviderIdAndEmployeeIdAndStatusAndStartsAtAfter(UUID providerId, UUID employeeId,
            AvailabilityStatus status, java.time.Instant after);

    /** The business's shared (no particular worker) slots of one status that start after the given moment. */
    List<AvailabilitySlot> findByProviderIdAndEmployeeIdIsNullAndStatusAndStartsAtAfter(UUID providerId,
            AvailabilityStatus status, java.time.Instant after);

    boolean existsByProviderIdAndStatus(UUID providerId, AvailabilityStatus status);

    /** The soonest OPEN slot, if any — presence/absence also answers "does this provider have open availability". */
    Optional<AvailabilitySlot> findFirstByProviderIdAndStatusOrderByStartsAtAsc(UUID providerId,
            AvailabilityStatus status);

    /** The soonest OPEN slot that has not started yet. */
    Optional<AvailabilitySlot> findFirstByProviderIdAndStatusAndStartsAtAfterOrderByStartsAtAsc(UUID providerId,
            AvailabilityStatus status, Instant after);

    /**
     * {@code providerinsights.BusinessAnalyticsService}'s utilization
     * input -- every slot (any status) this provider offered starting
     * within [from, to), used to compare booked duration against offered
     * duration for the same window.
     */
    List<AvailabilitySlot> findByProviderIdAndStartsAtBetween(UUID providerId, Instant from, Instant to);

    /**
     * Every existing slot (any status) whose [startsAt, endsAt) window
     * could overlap something in [windowStart, windowEnd) — fetched once
     * for the whole requested date range so RecurringScheduleService can
     * check every candidate slot in memory, not with one query per
     * candidate.
     */
    List<AvailabilitySlot> findByProviderIdAndStartsAtLessThanAndEndsAtGreaterThan(UUID providerId, Instant windowEnd,
            Instant windowStart);

    List<AvailabilitySlot> findByStatusAndStartsAtBetween(AvailabilityStatus status, Instant from, Instant to);
}
