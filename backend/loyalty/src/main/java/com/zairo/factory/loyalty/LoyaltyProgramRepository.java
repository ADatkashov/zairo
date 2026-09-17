package com.zairo.factory.loyalty;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoyaltyProgramRepository extends JpaRepository<LoyaltyProgram, UUID> {

    Optional<LoyaltyProgram> findByProviderId(UUID providerId);
}
