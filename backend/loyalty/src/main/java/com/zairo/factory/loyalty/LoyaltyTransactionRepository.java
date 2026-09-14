package com.zairo.factory.loyalty;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LoyaltyTransactionRepository extends JpaRepository<LoyaltyTransaction, UUID> {

    Page<LoyaltyTransaction> findByProviderIdAndUserIdOrderByCreatedAtDesc(UUID providerId, UUID userId,
            Pageable pageable);

    boolean existsByProviderIdAndUserIdAndReferenceTypeAndReferenceId(UUID providerId, UUID userId,
            LoyaltyReferenceType referenceType, UUID referenceId);

    /** Used by LoyaltyRefundProcessor to find how many points a completed, now-refunded booking originally earned. */
    Optional<LoyaltyTransaction> findFirstByProviderIdAndUserIdAndReferenceTypeAndReferenceId(UUID providerId,
            UUID userId, LoyaltyReferenceType referenceType, UUID referenceId);

    /**
     * Rolling-window earning cap check (see LoyaltyProgram's daily/monthly
     * caps) -- sums only points-adding rows so a redemption doesn't reduce
     * the amount the customer is considered to have "earned" for cap
     * purposes.
     */
    @Query("select coalesce(sum(t.pointsDelta), 0) from LoyaltyTransaction t "
            + "where t.providerId = :providerId and t.userId = :userId "
            + "and t.type in :types and t.createdAt >= :since")
    int sumPointsSince(@Param("providerId") UUID providerId, @Param("userId") UUID userId,
            @Param("types") List<LoyaltyTransactionType> types, @Param("since") Instant since);

    long countByProviderId(UUID providerId);

    List<LoyaltyTransaction> findByRedemptionId(UUID redemptionId);
}
