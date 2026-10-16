package com.zairo.factory.waitlist;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface WaitlistRepository extends JpaRepository<WaitlistEntry, UUID> {

    Optional<WaitlistEntry> findByUserIdAndProviderId(UUID userId, UUID providerId);

    List<WaitlistEntry> findByUserIdOrderByCreatedAtDesc(UUID userId);

    /** Who is waiting for a time that starts at {@code startsAt} at this business, other than the one who gave it up. */
    @Query("""
            select w from WaitlistEntry w
            where w.providerId = :providerId and w.userId <> :excludedUserId
              and (w.windowStart is null or w.windowStart <= :startsAt)
              and (w.windowEnd is null or w.windowEnd > :startsAt)
            order by w.createdAt
            """)
    List<WaitlistEntry> findWaitingFor(@Param("providerId") UUID providerId,
            @Param("excludedUserId") UUID excludedUserId, @Param("startsAt") Instant startsAt);

    @Transactional
    void deleteByUserIdAndProviderId(UUID userId, UUID providerId);

    /** Account deletion. */
    void deleteByUserId(UUID userId);
}
