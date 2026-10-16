package com.zairo.factory.booking;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BookingRepository extends JpaRepository<Booking, UUID> {

    List<Booking> findByUserId(UUID userId);

    List<Booking> findByUserIdAndCityCode(UUID userId, String cityCode);

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

    /** Account deletion guard: this user's bookings that are still live and whose slot hasn't started yet. */
    @Query(value = """
            select count(*) from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where b.user_id = :userId and b.status in ('PENDING', 'PENDING_PAYMENT', 'CONFIRMED')
              and s.starts_at > :now
            """, nativeQuery = true)
    long countUpcomingActiveByUserId(@Param("userId") UUID userId, @Param("now") Instant now);

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

    /**
     * The "your visit is tomorrow" reminder's target: a CONFIRMED booking whose slot starts within the window, that has
     * not had it yet and was made at least a day ahead (a booking made for later today needs no "tomorrow" reminder; the
     * one-hour reminder covers it).
     */
    @Query(value = """
            select b.* from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where b.status = 'CONFIRMED' and b.day_reminder_sent_at is null
              and s.starts_at > :from and s.starts_at <= :to
              and b.created_at <= s.starts_at - interval '24 hours'
            """, nativeQuery = true)
    List<Booking> findConfirmedBookingsForDayReminder(@Param("from") Instant from, @Param("to") Instant to);

    /** The platform dashboard's today/week/month and status-breakdown tiles — see platforminsights.PlatformInsightsService. */
    long countByCreatedAtBetween(Instant start, Instant end);

    long countByStatus(BookingStatus status);

    /** Status breakdown for a reporting window (both ends inclusive, like {@link #countByCreatedAtBetween}). */
    long countByStatusAndCreatedAtBetween(BookingStatus status, Instant start, Instant end);

    /**
     * Just the creation instants in a window — the platform trend/report
     * charts bucket these per day in one query instead of one COUNT per day.
     */
    @Query("select b.createdAt from Booking b where b.createdAt between :start and :end")
    List<Instant> findCreatedAtBetween(@Param("start") Instant start, @Param("end") Instant end);

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

    /**
     * {@code providerinsights.BusinessAnalyticsService}'s shared date-range
     * fetch behind every Business Analytics endpoint -- every booking whose
     * slot falls within [from, to), scoped to when the appointment happens
     * rather than when it was made. Same native-join shape as {@link
     * #findByProviderId}, just bounded so a reporting period doesn't load
     * this provider's entire booking history.
     */
    @Query(value = """
            select b.* from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId and s.starts_at >= :from and s.starts_at < :to
            """, nativeQuery = true)
    List<Booking> findByProviderIdAndSlotStartsAtBetween(@Param("providerId") UUID providerId,
            @Param("from") Instant from, @Param("to") Instant to);

    /**
     * {@code rebookengine.RebookStrategy}/{@code RebookCampaignService}'s
     * visit-history lookup — every COMPLETED booking a customer has with a
     * given provider, oldest first, used to establish their usual visit
     * interval. Same native-join shape as {@link #findByProviderId} (booking
     * has no direct providerId column); ordered by the slot's own {@code
     * starts_at} rather than {@code created_at} since a customer may book
     * appointments out of creation order.
     */
    @Query(value = """
            select b.* from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where b.user_id = :userId and s.provider_id = :providerId and b.status = 'COMPLETED'
            order by s.starts_at asc
            """, nativeQuery = true)
    List<Booking> findCompletedByUserIdAndProviderIdOrderByVisitDate(@Param("userId") UUID userId,
            @Param("providerId") UUID providerId);

    /**
     * {@code customerintelligence.BookingHistoryReader}'s provider-scoped
     * fetch -- every booking (any status) a customer has ever made with one
     * specific provider, used to compute {@code CustomerProviderProfile}.
     * Same native-join shape as {@link #findCompletedByUserIdAndProviderIdOrderByVisitDate}
     * (booking has no direct providerId column), just without the status
     * filter since intelligence needs cancellations/no-shows too, not only
     * completions.
     */
    @Query(value = """
            select b.* from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where b.user_id = :userId and s.provider_id = :providerId
            """, nativeQuery = true)
    List<Booking> findByUserIdAndProviderId(@Param("userId") UUID userId, @Param("providerId") UUID providerId);

    /**
     * {@code reactivationengine}'s discovery-sweep target -- every distinct
     * (customer, provider) pair's single most recent COMPLETED visit,
     * across the whole platform. {@code distinct on} (Postgres-specific,
     * fine since Flyway already targets Postgres only) rather than a
     * {@code group by max(starts_at)} because the sweep needs the actual
     * booking id of that latest visit, not just its timestamp -- it's the
     * anchor a {@code ReactivationCampaign} is keyed on. Deliberately not
     * filtered by any inactivity cutoff here: filtering by {@code
     * starts_at < cutoff} before picking "the latest" would let an older
     * row win the pick for a customer whose true latest visit happens to
     * fall inside the cutoff (i.e. isn't actually inactive) -- correctness
     * over one fewer full-table scan, since this runs at most once a day.
     */
    @Query(value = """
            select distinct on (b.user_id, s.provider_id)
                   b.id as bookingId, b.user_id as userId, s.provider_id as providerId, s.starts_at as lastVisitAt
            from booking b
            join availability_slot s on s.id = b.availability_slot_id
            where b.status = 'COMPLETED'
            order by b.user_id, s.provider_id, s.starts_at desc
            """, nativeQuery = true)
    List<LatestCompletedVisitRow> findLatestCompletedVisitPerUserAndProvider();

    interface LatestCompletedVisitRow {
        UUID getBookingId();

        UUID getUserId();

        UUID getProviderId();

        Instant getLastVisitAt();
    }
}
