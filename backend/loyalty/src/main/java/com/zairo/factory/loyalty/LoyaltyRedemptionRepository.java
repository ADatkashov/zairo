package com.zairo.factory.loyalty;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoyaltyRedemptionRepository extends JpaRepository<LoyaltyRedemption, UUID> {

    Optional<LoyaltyRedemption> findByCode(String code);

    boolean existsByCode(String code);

    Page<LoyaltyRedemption> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Page<LoyaltyRedemption> findByProviderIdOrderByCreatedAtDesc(UUID providerId, Pageable pageable);

    long countByProviderIdAndStatus(UUID providerId, LoyaltyRedemptionStatus status);

    List<LoyaltyRedemption> findByStatusAndExpiresAtBefore(LoyaltyRedemptionStatus status, Instant cutoff);

    /** Used by LoyaltyRedemptionService#applyToBooking to enforce the program's per-booking points cap. */
    List<LoyaltyRedemption> findByAppliedBookingIdAndStatus(UUID appliedBookingId, LoyaltyRedemptionStatus status);
}
