package com.zairo.factory.booking;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BookingRepository extends JpaRepository<Booking, UUID> {

    List<Booking> findByUserId(UUID userId);

    /**
     * Every booking (any status, any provider) for a whole set of
     * candidate users in one query -- {@code smartfill.CandidateFinder}'s
     * bulk fetch for conflict/category-interest/recent-engagement/
     * suitable-time signals across an entire candidate pool at once,
     * instead of one {@link #findByUserId} call per candidate.
     */
    List<Booking> findByUserIdIn(List<UUID> userIds);

    List<Booking> findByAvailabilitySlotIdIn(List<UUID> availabilitySlotIds);

    /** BookingPaymentTimeoutJob's sweep target — a booking that's sat unpaid past the configured timeout. */
    List<Booking> findByStatusAndCreatedAtBefore(BookingStatus status, Instant cutoff);

    /**
     * BookingReminderJob's target — a CONFIRMED booking whose slot starts
     * within the given window and hasn't been reminded about yet. A native
     * join because, like {@link #findByProviderId}, the slot's own
     * {@code starts_at} isn't a column on {@code booking} itself.
     */
    @Query(value = """
            select b.* from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where b.status = 'CONFIRMED' and b.reminder_sent_at is null
              and s.starts_at > :now and s.starts_at <= :reminderCutoff
            """, nativeQuery = true)
    List<Booking> findConfirmedBookingsStartingBeforeAndNotYetReminded(@Param("now") Instant now,
            @Param("reminderCutoff") Instant reminderCutoff);

    /** The platform dashboard's today/week/month and status-breakdown tiles — see platforminsights.PlatformInsightsService. */
    long countByCreatedAtBetween(Instant start, Instant end);

    long countByStatus(BookingStatus status);

    /**
     * Every booking ever made against this provider, regardless of status —
     * same join shape as {@link #countByProviderIdAndCreatedAtBetween},
     * reused here to list rather than just count (see
     * {@code providerinsights.ProviderInsightsService}, the business
     * customer-history read).
     */
    @Query(value = """
            select b.* from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId
            """, nativeQuery = true)
    List<Booking> findByProviderId(@Param("providerId") UUID providerId);

    /**
     * Booking has no direct providerId column (see Booking's own doc
     * comment on the bounded-context boundary) — provider is reached only
     * via availability_slot, so this is a native join rather than a
     * derived query, same shape as ReviewRepository's aggregate query ("one
     * query, not N+1").
     */
    @Query(value = """
            select count(*) from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId and b.created_at >= :monthStart and b.created_at < :monthEnd
            """, nativeQuery = true)
    long countByProviderIdAndCreatedAtBetween(@Param("providerId") UUID providerId,
            @Param("monthStart") Instant monthStart, @Param("monthEnd") Instant monthEnd);
}
