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

    boolean existsByBookingId(UUID bookingId);

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
                   (select avg(r2.rating) from review r2) as globalAverageRating
            from review r
            join booking b on b.id = r.booking_id
            join availability_slot s on s.id = b.availability_slot_id
            where s.provider_id in (:providerIds)
            group by s.provider_id
            """, nativeQuery = true)
    List<ProviderRatingRow> aggregateRatingsByProviderIds(@Param("providerIds") Collection<UUID> providerIds);

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
                   r.business_reply_at as businessReplyAt
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
    Page<ProviderReviewRow> findByProviderId(@Param("providerId") UUID providerId, Pageable pageable);

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
}
