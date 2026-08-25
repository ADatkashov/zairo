package com.zairo.factory.subscriptions;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubscriptionChargeRepository extends JpaRepository<SubscriptionCharge, UUID> {

    List<SubscriptionCharge> findBySubscriptionId(UUID subscriptionId);

    /**
     * The renewal job's idempotency lookup: is there already a charge
     * attempt for the subscription's *current* billing period (i.e. created
     * on/after it started)? If it's FAILED, the job reuses that same row
     * (same id = same idempotency key) instead of minting a new one — exact
     * same reasoning as {@code PaymentsService.createPayment}.
     */
    Optional<SubscriptionCharge> findFirstBySubscriptionIdAndCreatedAtGreaterThanEqualOrderByCreatedAtDesc(
            UUID subscriptionId, Instant periodStart);
}
