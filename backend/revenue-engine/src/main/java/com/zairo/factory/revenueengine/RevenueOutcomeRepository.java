package com.zairo.factory.revenueengine;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RevenueOutcomeRepository extends JpaRepository<RevenueOutcome, UUID> {

    Optional<RevenueOutcome> findByActionTypeAndTriggerRefId(ActionType actionType, UUID triggerRefId);

    /** provider-insights' "Revenue Recovered by ZAIRO" panel — every decision ever made for this provider. */
    List<RevenueOutcome> findByProviderId(UUID providerId);

    /** The same panel's date-scoped variant — the Business Analytics dashboard's selected reporting period. */
    List<RevenueOutcome> findByProviderIdAndDecidedAtBetween(UUID providerId, Instant from, Instant to);
}
