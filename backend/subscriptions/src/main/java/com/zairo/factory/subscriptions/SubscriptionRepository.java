package com.zairo.factory.subscriptions;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SubscriptionRepository extends JpaRepository<Subscription, UUID> {

    Optional<Subscription> findByOwnerUserId(UUID ownerUserId);

    /** FREE is never billed — the renewal job only ever needs paid plans that are due. */
    List<Subscription> findByPlanNotAndStatusAndCurrentPeriodEndBefore(SubscriptionPlan plan,
            SubscriptionStatus status, Instant before);

    List<Subscription> findByStatusAndGracePeriodEndsAtBefore(SubscriptionStatus status, Instant before);

    /**
     * PAST_DUE subscriptions still inside their grace period and not touched
     * since {@code touchedBefore} — the daily retry's candidates. The
     * "not touched recently" part is what keeps it to about one attempt a
     * day: every attempt (and the original failure) stamps {@code updatedAt}.
     */
    List<Subscription> findByStatusAndGracePeriodEndsAtAfterAndUpdatedAtBefore(SubscriptionStatus status,
            Instant graceEndsAfter, Instant touchedBefore);

    /**
     * Row lock for the duration of the caller's transaction. Billing takes it
     * before charging so two overlapping runs (a second app instance, a
     * manual retry racing the daily job) can never both charge the same
     * subscription: the second one blocks here, then re-reads the committed
     * state and sees there is nothing left to do.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from Subscription s where s.id = :id")
    Optional<Subscription> findByIdForUpdate(@Param("id") UUID id);

    /** The platform dashboard's plan/status breakdown — see platforminsights.PlatformInsightsService. */
    long countByPlan(SubscriptionPlan plan);

    long countByStatus(SubscriptionStatus status);
}
