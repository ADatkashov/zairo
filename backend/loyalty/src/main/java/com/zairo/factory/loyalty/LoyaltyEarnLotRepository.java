package com.zairo.factory.loyalty;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LoyaltyEarnLotRepository extends JpaRepository<LoyaltyEarnLot, UUID> {

    /** FIFO consumption order for both redemption and expiration -- oldest earned points go first. */
    List<LoyaltyEarnLot> findByProviderIdAndUserIdAndPointsRemainingGreaterThanOrderByEarnedAtAsc(UUID providerId,
            UUID userId, int minRemaining);

    /**
     * The expiration sweep's target, one page at a time -- indexed on
     * {@code expires_at} (see V57) so a due lot is found without scanning
     * every account's full history (Phase 23 performance guidance).
     */
    List<LoyaltyEarnLot> findByExpiresAtBeforeAndPointsRemainingGreaterThanOrderByExpiresAtAsc(Instant cutoff,
            int minRemaining, Pageable pageable);

    @Query("select coalesce(sum(l.pointsRemaining), 0) from LoyaltyEarnLot l "
            + "where l.providerId = :providerId and l.userId = :userId "
            + "and l.expiresAt is not null and l.expiresAt <= :cutoff and l.pointsRemaining > 0")
    int sumExpiringBy(@Param("providerId") UUID providerId, @Param("userId") UUID userId,
            @Param("cutoff") Instant cutoff);
}
