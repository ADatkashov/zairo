package com.zairo.factory.reviews;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ReviewRepository extends JpaRepository<Review, UUID> {

    Optional<Review> findByBookingId(UUID bookingId);

    /** Reports waiting for a platform decision (the dashboard's "to review" count). */
    @Query("select count(r) from Review r where r.reportedAt is not null and r.reportResolvedAt is null")
    long countOpenReports();

    boolean existsByBookingId(UUID bookingId);

    List<Review> findByBookingIdIn(Collection<UUID> bookingIds);

    /**
     * One aggregate query for every requested provider at once, not one
     * query per provider — that per-provider-loop shape is exactly the
     * "expensive join on every search request" ADR-0002's search module
     * javadoc flagged as premature. Review has no direct providerId
     * column (see Review's own doc comment) — every hop of
     * review -> booking -> availability_slot -> provider is indexed
     * (review.booking_id and booking.availability_slot_id are unique
     * indexes, availability_slot.provider_id has a plain index), so this
     * is a chain of indexed equi-joins, not an unbounded cross join.
     * Providers with zero reviews simply don't appear in the result —
     * callers treat "absent" as "no rating yet", not as zero.
     *
     * Also computes the global average (across all requested providers) for
     * Bayesian rating calculation — see {@link ReviewSummaryService} for usage.
     */
    @Query(value = """
            select s.provider_id as providerId,
                   avg(r.rating) as averageRating,
                   count(*) as reviewCount,
                   (select avg(r2.rating) from review r2 where r2.hidden_at is null) as globalAverageRating
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id in (:providerIds) and r.hidden_at is null
            group by s.provider_id
            """, nativeQuery = true)
    List<ProviderRatingRow> aggregateRatingsByProviderIds(@Param("providerIds") Collection<UUID> providerIds);

    /**
     * Average rating and number of the visible reviews a provider received in [from, to) — the weekly report's
     * "how did the week feel". Same review -> booking -> slot join as {@link #aggregateRatingsByProviderIds}.
     */
    @Query(value = """
            select avg(r.rating) as averageRating, count(*) as reviewCount
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId and r.hidden_at is null
              and r.created_at >= :from and r.created_at < :to
            """, nativeQuery = true)
    PeriodRatingRow ratingInPeriod(@Param("providerId") UUID providerId, @Param("from") java.time.Instant from,
            @Param("to") java.time.Instant to);

    interface PeriodRatingRow {
        /** Null when there were no reviews. */
        Double getAverageRating();

        long getReviewCount();
    }

    interface ProviderRatingRow {
        UUID getProviderId();

        double getAverageRating();

        long getReviewCount();

        Double getGlobalAverageRating();
    }

    /**
     * The owner-facing reviews list, newest first — same indexed
     * review -> booking -> availability_slot -> provider join as {@link
     * #aggregateRatingsByProviderIds}, just filtered to one provider and
     * paginated instead of aggregated. Carries {@code userId} along (Review
     * itself has no such column, see {@code Review}'s doc comment) so the
     * caller can resolve reviewer names in one batch instead of re-joining.
     */
    @Query(value = """
            select r.id as id, r.booking_id as bookingId, b.user_id as userId, r.rating as rating,
                   r.comment as comment, r.created_at as createdAt, r.business_reply as businessReply,
                   r.business_reply_at as businessReplyAt, r.reported_at as reportedAt,
                   r.report_resolved_at as reportResolvedAt, r.hidden_at as hiddenAt
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId
            order by r.created_at desc
            """,
            countQuery = """
            select count(*)
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId
            """,
            nativeQuery = true)
    Page<OwnerReviewRow> findByProviderId(@Param("providerId") UUID providerId, Pageable pageable);

    interface ProviderReviewRow {
        UUID getId();

        UUID getBookingId();

        UUID getUserId();

        int getRating();

        String getComment();

        Instant getCreatedAt();

        String getBusinessReply();

        Instant getBusinessReplyAt();
    }

    /** The owner's row: the same plus where the review stands in moderation. */
    interface OwnerReviewRow extends ProviderReviewRow {
        Instant getReportedAt();

        Instant getReportResolvedAt();

        Instant getHiddenAt();
    }

    /** The platform's moderation queue: reported (or hidden) reviews with the business they are about. */
    @Query(value = """
            select r.id as id, r.booking_id as bookingId, r.rating as rating, r.comment as comment,
                   r.created_at as createdAt, r.business_reply as businessReply, r.report_reason as reportReason,
                   r.reported_at as reportedAt, r.report_resolved_at as reportResolvedAt, r.hidden_at as hiddenAt,
                   r.hidden_reason as hiddenReason, s.provider_id as providerId, p.name as providerName
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            join provider p on p.id = s.provider_id
            where (:status = 'OPEN' and r.reported_at is not null and r.report_resolved_at is null)
               or (:status = 'HIDDEN' and r.hidden_at is not null)
               or (:status = 'DISMISSED' and r.reported_at is not null and r.report_resolved_at is not null
                   and r.hidden_at is null)
            order by coalesce(r.reported_at, r.hidden_at) desc
            """,
            countQuery = """
            select count(*)
            from review r
            where (:status = 'OPEN' and r.reported_at is not null and r.report_resolved_at is null)
               or (:status = 'HIDDEN' and r.hidden_at is not null)
               or (:status = 'DISMISSED' and r.reported_at is not null and r.report_resolved_at is not null
                   and r.hidden_at is null)
            """,
            nativeQuery = true)
    Page<ModerationRow> findForModeration(@Param("status") String status, Pageable pageable);

    interface ModerationRow {
        UUID getId();

        UUID getBookingId();

        int getRating();

        String getComment();

        Instant getCreatedAt();

        String getBusinessReply();

        String getReportReason();

        Instant getReportedAt();

        Instant getReportResolvedAt();

        Instant getHiddenAt();

        String getHiddenReason();

        UUID getProviderId();

        String getProviderName();
    }

    /**
     * Review count per star for one provider — same indexed join as the
     * queries above, grouped by rating. Stars nobody gave simply don't
     * appear; {@link ReviewSummaryService}-style callers fill the gaps with 0.
     */
    @Query(value = """
            select r.rating as rating, count(*) as total
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId and r.hidden_at is null
            group by r.rating
            """, nativeQuery = true)
    List<RatingCountRow> countByRatingForProvider(@Param("providerId") UUID providerId);

    interface RatingCountRow {
        int getRating();

        long getTotal();
    }

    /**
     * The public list with optional filters. {@code rating} null = any star;
     * {@code withCommentOnly} drops reviews that are just a star count;
     * {@code sort} is one of newest / highest / lowest (ties always newest
     * first). The ORDER BY is a fixed CASE, not a client-supplied column, so
     * there is nothing to inject; callers pass an unsorted Pageable.
     */
    @Query(value = """
            select r.id as id, r.booking_id as bookingId, b.user_id as userId, r.rating as rating,
                   r.comment as comment, r.created_at as createdAt, r.business_reply as businessReply,
                   r.business_reply_at as businessReplyAt
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId and r.hidden_at is null
              and (cast(:rating as integer) is null or r.rating = cast(:rating as integer))
              and (:withCommentOnly = false or (r.comment is not null and btrim(r.comment) <> ''))
            order by case when :sort = 'highest' then r.rating end desc nulls last,
                     case when :sort = 'lowest' then r.rating end asc nulls last,
                     r.created_at desc
            """,
            countQuery = """
            select count(*)
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id = :providerId and r.hidden_at is null
              and (cast(:rating as integer) is null or r.rating = cast(:rating as integer))
              and (:withCommentOnly = false or (r.comment is not null and btrim(r.comment) <> ''))
            """,
            nativeQuery = true)
    Page<ProviderReviewRow> findPublic(@Param("providerId") UUID providerId, @Param("rating") Integer rating,
            @Param("withCommentOnly") boolean withCommentOnly, @Param("sort") String sort, Pageable pageable);
}
