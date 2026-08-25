package com.zairo.factory.subscriptions;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubscriptionRepository extends JpaRepository<Subscription, UUID> {

    Optional<Subscription> findByOwnerUserId(UUID ownerUserId);

    /** FREE is never billed — the renewal job only ever needs paid plans that are due. */
    List<Subscription> findByPlanNotAndStatusAndCurrentPeriodEndBefore(SubscriptionPlan plan,
            SubscriptionStatus status, Instant before);

    List<Subscription> findByStatusAndGracePeriodEndsAtBefore(SubscriptionStatus status, Instant before);
}
