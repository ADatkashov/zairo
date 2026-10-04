package com.zairo.factory.loyalty;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoyaltyProgramRepository extends JpaRepository<LoyaltyProgram, UUID> {

    Optional<LoyaltyProgram> findByProviderId(UUID providerId);

    /** Programs that are switched on and actually grant a birthday bonus -- the daily sweep's work list. */
    java.util.List<LoyaltyProgram> findByEnabledTrueAndBirthdayBonusPointsGreaterThan(int points);
}
