package com.zairo.factory.loyalty;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LoyaltyRewardRepository extends JpaRepository<LoyaltyReward, UUID> {

    List<LoyaltyReward> findByProviderIdOrderByPointsCostAsc(UUID providerId);

    @Query("select r from LoyaltyReward r where r.providerId = :providerId and r.active = true "
            + "and (r.startsAt is null or r.startsAt <= :now) and (r.endsAt is null or r.endsAt >= :now) "
            + "order by r.pointsCost asc")
    List<LoyaltyReward> findRedeemableNow(@Param("providerId") UUID providerId, @Param("now") Instant now);
}
