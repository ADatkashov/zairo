package com.zairo.factory.loyalty;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoyaltyMilestoneRuleRepository extends JpaRepository<LoyaltyMilestoneRule, UUID> {

    List<LoyaltyMilestoneRule> findByProgramIdOrderByVisitsRequiredAsc(UUID programId);

    void deleteByProgramId(UUID programId);
}
