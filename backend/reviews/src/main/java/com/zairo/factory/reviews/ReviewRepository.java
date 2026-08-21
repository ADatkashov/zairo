package com.zairo.factory.reviews;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
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
     */
    @Query(value = """
            select s.provider_id as providerId, avg(r.rating) as averageRating, count(*) as reviewCount
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
    }
}
