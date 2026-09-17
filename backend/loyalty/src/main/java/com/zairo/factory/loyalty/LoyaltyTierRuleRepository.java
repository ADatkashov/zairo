package com.zairo.factory.loyalty;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoyaltyTierRuleRepository extends JpaRepository<LoyaltyTierRule, UUID> {

    List<LoyaltyTierRule> findByProgramIdOrderByMinLifetimePointsAsc(UUID programId);

    void deleteByProgramId(UUID programId);
}
