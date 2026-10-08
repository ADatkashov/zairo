package com.zairo.factory.subscriptions;

import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

/**
 * The recurring side of billing — {@link SubscriptionRenewalJob} calls
 * {@link #renewDueSubscriptions()}, {@link #retryPastDueSubscriptions()} and
 * {@link #downgradeExpiredGracePeriods()} once a day. Each subscription is
 * processed in its own transaction (not one for the whole batch): a single
 * subscription's failure shouldn't roll back everyone else's renewal, the
 * same principle {@code PaymentsService.charge} applies by not rethrowing a
 * provider failure and losing the whole request.
 *
 * <p>The transaction is opened with a {@link TransactionTemplate} rather than
 * {@code @Transactional} on a private helper: a method called from inside the
 * same class bypasses Spring's proxy, so such an annotation would silently do
 * nothing. Inside it the subscription row is locked and its state re-checked
 * <em>before</em> any charge, so two overlapping runs cannot both charge it.
 */
@Service
public class SubscriptionRenewalService {

    /**
     * A real grace window, not an arbitrary number — long enough that a
     * transient card issue doesn't instantly cut an owner off, short enough
     * that a genuinely lapsed subscription doesn't linger on PRO for free.
     */
    static final int GRACE_PERIOD_DAYS = 7;

    /** A PAST_DUE subscription is retried at most this often, so the daily job means one attempt a day. */
    private static final int RETRY_MIN_HOURS_SINCE_LAST_ATTEMPT = 12;

    private static final Logger log = LoggerFactory.getLogger(SubscriptionRenewalService.class);

    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionChargeRepository subscriptionChargeRepository;
    private final PaymentProvider paymentProvider;
    private final PaymentProviderName providerName;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;
    private final String defaultCurrency;
    private final TransactionTemplate transactionTemplate;

    public SubscriptionRenewalService(SubscriptionRepository subscriptionRepository,
            SubscriptionChargeRepository subscriptionChargeRepository, PaymentProvider paymentProvider,
            @Value("${payment.provider:mock}") String providerName, ApplicationEventPublisher eventPublisher,
            Clock clock, @Value("${app.platform.default-currency:USD}") String defaultCurrency,
            PlatformTransactionManager transactionManager) {
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionChargeRepository = subscriptionChargeRepository;
        this.paymentProvider = paymentProvider;
        this.providerName = PaymentProviderName.valueOf(providerName.toUpperCase());
        this.eventPublisher = eventPublisher;
        this.clock = clock;
        this.defaultCurrency = defaultCurrency;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    public void renewDueSubscriptions() {
        Instant now = clock.instant();
        List<Subscription> due = subscriptionRepository
                .findByPlanNotAndStatusAndCurrentPeriodEndBefore(SubscriptionPlan.FREE, SubscriptionStatus.ACTIVE,
                        now);
        for (Subscription subscription : due) {
            inOwnTransaction(subscription.getId(), "renew", this::renewOrDowngradeOne);
        }
    }

    /**
     * Tries again to charge every PAST_DUE subscription that is still inside
     * its grace period — a declined card or a provider outage is usually
     * gone a day later, and without this the owner would only be rescued by
     * pressing "Fix" themselves. Roughly one attempt a day (see {@link
     * #RETRY_MIN_HOURS_SINCE_LAST_ATTEMPT}); a successful charge renews the
     * subscription and ends the grace period, a failed one leaves the
     * original grace window untouched and does not email the owner again.
     */
    public void retryPastDueSubscriptions() {
        Instant now = clock.instant();
        List<Subscription> candidates = subscriptionRepository
                .findByStatusAndGracePeriodEndsAtAfterAndUpdatedAtBefore(SubscriptionStatus.PAST_DUE, now,
                        now.minus(RETRY_MIN_HOURS_SINCE_LAST_ATTEMPT, ChronoUnit.HOURS));
        for (Subscription subscription : candidates) {
            inOwnTransaction(subscription.getId(), "retry", this::retryPastDueOne);
        }
    }

    /**
     * Any {@code PAST_DUE} subscription whose grace period has expired
     * without a successful retry gets force-downgraded — existing
     * providers/staff/bookings are never deleted or blocked retroactively,
     * only *new* creation starts failing against FREE's limits (the same 4
     * checks {@link SubscriptionLimitService} already enforces).
     */
    public void downgradeExpiredGracePeriods() {
        Instant now = clock.instant();
        List<Subscription> expired = subscriptionRepository
                .findByStatusAndGracePeriodEndsAtBefore(SubscriptionStatus.PAST_DUE, now);
        for (Subscription subscription : expired) {
            inOwnTransaction(subscription.getId(), "downgrade", this::downgradeOne);
        }
    }

    /**
     * Owner-triggered "Fix" action (Billing screen's grace-period banner —
     * v2 design audit) — the same charge path {@link #chargeForRenewal}
     * already runs from the daily sweep, just invoked immediately instead
     * of waiting for the next one. A no-op guard: retrying only makes sense
     * while the subscription is actually PAST_DUE.
     */
    @Transactional
    public Subscription retryPastDueCharge(UUID ownerUserId) {
        UUID subscriptionId = subscriptionRepository.findByOwnerUserId(ownerUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Subscription not found for owner: " + ownerUserId))
                .getId();
        // Locked, then the status is checked: a daily-job retry that already
        // rescued this subscription turns this click into a 409, not a second charge.
        Subscription subscription = subscriptionRepository.findByIdForUpdate(subscriptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Subscription not found: " + subscriptionId));
        if (subscription.getStatus() != SubscriptionStatus.PAST_DUE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Subscription is not past due.");
        }
        chargeForRenewal(subscription);
        return subscription;
    }

    /** Runs {@code action} for one subscription in its own transaction; a failure is logged, never allowed to stop the batch. */
    private void inOwnTransaction(UUID subscriptionId, String what, java.util.function.Consumer<UUID> action) {
        try {
            transactionTemplate.executeWithoutResult(status -> action.accept(subscriptionId));
        } catch (RuntimeException e) {
            log.error("Subscription {} failed ({}): {}", subscriptionId, what, e.toString(), e);
        }
    }

    private Subscription lock(UUID subscriptionId) {
        return subscriptionRepository.findByIdForUpdate(subscriptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Subscription not found: "
                        + subscriptionId));
    }

    private void renewOrDowngradeOne(UUID subscriptionId) {
        Subscription subscription = lock(subscriptionId);
        // Re-checked under the lock: another run may have renewed/downgraded it since the batch was listed.
        if (subscription.getPlan() == SubscriptionPlan.FREE || subscription.getStatus() != SubscriptionStatus.ACTIVE
                || !subscription.getCurrentPeriodEnd().isBefore(clock.instant())) {
            return;
        }

        if (subscription.isCancelAtPeriodEnd()) {
            subscription.downgradeToFree(clock.instant());
            subscriptionRepository.save(subscription);
            eventPublisher.publishEvent(new SubscriptionPastDueEvent(subscription.getId(),
                    subscription.getOwnerUserId()));
            return;
        }

        chargeForRenewal(subscription);
    }

    private void retryPastDueOne(UUID subscriptionId) {
        Subscription subscription = lock(subscriptionId);
        Instant now = clock.instant();
        if (subscription.getPlan() == SubscriptionPlan.FREE || subscription.getStatus() != SubscriptionStatus.PAST_DUE
                || subscription.getGracePeriodEndsAt() == null || !subscription.getGracePeriodEndsAt().isAfter(now)
                || !subscription.getUpdatedAt().isBefore(now.minus(RETRY_MIN_HOURS_SINCE_LAST_ATTEMPT,
                        ChronoUnit.HOURS))) {
            return;
        }
        chargeForRenewal(subscription);
    }

    private void downgradeOne(UUID subscriptionId) {
        Subscription subscription = lock(subscriptionId);
        Instant now = clock.instant();
        if (subscription.getStatus() != SubscriptionStatus.PAST_DUE || subscription.getGracePeriodEndsAt() == null
                || !subscription.getGracePeriodEndsAt().isBefore(now)) {
            return;
        }
        subscription.downgradeToFree(now);
        subscriptionRepository.save(subscription);
        eventPublisher.publishEvent(new SubscriptionPastDueEvent(subscription.getId(),
                subscription.getOwnerUserId()));
    }

    private void chargeForRenewal(Subscription subscription) {
        SubscriptionPlan plan = subscription.getPlan();
        Instant now = clock.instant();
        String recurringProfileId = recurringProfileIdFor(subscription);

        SubscriptionCharge charge = subscriptionChargeRepository
                .findFirstBySubscriptionIdAndCreatedAtGreaterThanEqualOrderByCreatedAtDesc(subscription.getId(),
                        subscription.getCurrentPeriodStart())
                .filter(existing -> existing.getStatus() == SubscriptionChargeStatus.FAILED)
                .orElseGet(() -> subscriptionChargeRepository.save(new SubscriptionCharge(UUID.randomUUID(),
                        subscription.getId(), plan.monthlyPrice, defaultCurrency, providerName, recurringProfileId,
                        now)));

        PaymentProvider.ChargeResult result;
        try {
            result = paymentProvider.chargeRecurring(recurringProfileId, charge.getId(), charge.getAmount(),
                    charge.getCurrency());
        } catch (RuntimeException e) {
            charge.markFailed("Payment provider error: " + e.getMessage(), now);
            subscriptionChargeRepository.save(charge);
            markPastDue(subscription, now);
            return;
        }

        if (result.succeeded()) {
            charge.markSucceeded(result.providerReference(), now);
            subscriptionChargeRepository.save(charge);
            subscription.markRenewed(now);
            subscriptionRepository.save(subscription);
            eventPublisher.publishEvent(new SubscriptionRenewedEvent(subscription.getId(),
                    subscription.getOwnerUserId(), subscription.getPlan()));
        } else {
            charge.markFailed(result.failureReason(), now);
            subscriptionChargeRepository.save(charge);
            markPastDue(subscription, now);
        }
    }

    /**
     * Freedom Pay only hands back {@code pg_recurring_profile_id} on the
     * upgrade charge that first created it (see {@code SubscriptionCharge}'s
     * doc comment) — every renewal after that looks back for the most
     * recent charge that carried one, rather than assuming the current
     * period's own (possibly not-yet-created) charge row has it.
     */
    private String recurringProfileIdFor(Subscription subscription) {
        return subscriptionChargeRepository
                .findFirstBySubscriptionIdAndRecurringProfileIdIsNotNullOrderByCreatedAtDesc(subscription.getId())
                .map(SubscriptionCharge::getRecurringProfileId)
                .orElse(null);
    }

    private void markPastDue(Subscription subscription, Instant now) {
        // The "payment failed" email goes out on the first failure only — the
        // owner is already in the grace period and told so; a retry that
        // fails again must not mail them every day.
        boolean firstFailure = subscription.getStatus() != SubscriptionStatus.PAST_DUE;
        Instant gracePeriodEndsAt = now.plus(GRACE_PERIOD_DAYS, ChronoUnit.DAYS);
        subscription.markPastDue(now, gracePeriodEndsAt);
        subscriptionRepository.save(subscription);
        if (firstFailure) {
            eventPublisher.publishEvent(new SubscriptionPaymentFailedEvent(subscription.getId(),
                    subscription.getOwnerUserId(), subscription.getGracePeriodEndsAt()));
        }
    }
}
