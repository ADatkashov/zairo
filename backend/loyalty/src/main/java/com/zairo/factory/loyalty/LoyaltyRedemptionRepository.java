package com.zairo.factory.loyalty;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LoyaltyRedemptionRepository extends JpaRepository<LoyaltyRedemption, UUID> {

    Optional<LoyaltyRedemption> findByCode(String code);

    boolean existsByCode(String code);

    Page<LoyaltyRedemption> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Page<LoyaltyRedemption> findByProviderIdOrderByCreatedAtDesc(UUID providerId, Pageable pageable);

    long countByProviderIdAndStatus(UUID providerId, LoyaltyRedemptionStatus status);

    List<LoyaltyRedemption> findByStatusAndExpiresAtBefore(LoyaltyRedemptionStatus status, Instant cutoff);

    /** Used by LoyaltyRedemptionService#applyToBooking to enforce the program's per-booking points cap. */
    List<LoyaltyRedemption> findByAppliedBookingIdAndStatus(UUID appliedBookingId, LoyaltyRedemptionStatus status);

    /**
     * Takes a row-level write lock on this one redemption for the whole
     * ACTIVE-status-transition operation (apply-to-booking, cancel) -- the
     * same "serialize instead of racing" guarantee {@code
     * LoyaltyAccountRepository#lockByProviderIdAndUserId} gives the earn/
     * redeem side. Two concurrent apply (or cancel) calls for the same code
     * would otherwise both read status ACTIVE before either writes.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from LoyaltyRedemption r where r.code = :code")
    Optional<LoyaltyRedemption> lockByCode(@Param("code") String code);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from LoyaltyRedemption r where r.id = :id")
    Optional<LoyaltyRedemption> lockById(@Param("id") UUID id);
}
