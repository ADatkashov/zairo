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

    /**
     * The renewal job's source of the recurring profile to charge — Freedom
     * Pay only returns {@code pg_recurring_profile_id} on the upgrade charge
     * that created it, so every later renewal has to look back for the most
     * recent charge that carried one (see {@code SubscriptionCharge}'s own
     * doc comment).
     */
    Optional<SubscriptionCharge> findFirstBySubscriptionIdAndRecurringProfileIdIsNotNullOrderByCreatedAtDesc(
            UUID subscriptionId);

    /** MRR's source data — see platforminsights.PlatformInsightsService. */
    List<SubscriptionCharge> findByStatusAndCreatedAtBetween(SubscriptionChargeStatus status, Instant start,
            Instant end);

    /** {@code SubscriptionService.upgradeToPro}'s idempotency guard: is a checkout already pending for this subscription? */
    Optional<SubscriptionCharge> findFirstBySubscriptionIdAndStatusOrderByCreatedAtDesc(UUID subscriptionId,
            SubscriptionChargeStatus status);
}
