package com.zairo.factory.booking;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BookingRepository extends JpaRepository<Booking, UUID> {

    List<Booking> findByUserId(UUID userId);

    List<Booking> findByAvailabilitySlotIdIn(List<UUID> availabilitySlotIds);

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
