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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

/**
 * The recurring side of billing — {@link SubscriptionRenewalJob} calls
 * {@link #renewDueSubscriptions()} once a day. One {@code @Transactional}
 * per subscription (not one transaction for the whole batch): a single
 * subscription's failure shouldn't roll back everyone else's renewal, the
 * same principle {@code PaymentsService.charge} applies by not rethrowing a
 * provider failure and losing the whole request.
 */
@Service
public class SubscriptionRenewalService {

    /**
     * A real grace window, not an arbitrary number — long enough that a
     * transient card issue doesn't instantly cut an owner off, short enough
     * that a genuinely lapsed subscription doesn't linger on PRO for free.
     */
    static final int GRACE_PERIOD_DAYS = 7;

    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionChargeRepository subscriptionChargeRepository;
    private final PaymentProvider paymentProvider;
    private final PaymentProviderName providerName;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;
    private final String defaultCurrency;

    public SubscriptionRenewalService(SubscriptionRepository subscriptionRepository,
            SubscriptionChargeRepository subscriptionChargeRepository, PaymentProvider paymentProvider,
            @Value("${payment.provider:mock}") String providerName, ApplicationEventPublisher eventPublisher,
            Clock clock, @Value("${app.platform.default-currency:USD}") String defaultCurrency) {
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionChargeRepository = subscriptionChargeRepository;
        this.paymentProvider = paymentProvider;
        this.providerName = PaymentProviderName.valueOf(providerName.toUpperCase());
        this.eventPublisher = eventPublisher;
        this.clock = clock;
        this.defaultCurrency = defaultCurrency;
    }

    public void renewDueSubscriptions() {
        Instant now = clock.instant();
        List<Subscription> due = subscriptionRepository
                .findByPlanNotAndStatusAndCurrentPeriodEndBefore(SubscriptionPlan.FREE, SubscriptionStatus.ACTIVE,
                        now);
        for (Subscription subscription : due) {
            renewOrDowngradeOne(subscription.getId());
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
            downgradeOne(subscription.getId());
        }
    }

    @Transactional
    void renewOrDowngradeOne(UUID subscriptionId) {
        Subscription subscription = subscriptionRepository.findById(subscriptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Subscription not found: "
                        + subscriptionId));

        if (subscription.isCancelAtPeriodEnd()) {
            subscription.downgradeToFree(clock.instant());
            subscriptionRepository.save(subscription);
            eventPublisher.publishEvent(new SubscriptionPastDueEvent(subscription.getId(),
                    subscription.getOwnerUserId()));
            return;
        }

        chargeForRenewal(subscription);
    }

    @Transactional
    void downgradeOne(UUID subscriptionId) {
        Subscription subscription = subscriptionRepository.findById(subscriptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Subscription not found: "
                        + subscriptionId));
        subscription.downgradeToFree(clock.instant());
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
        Instant gracePeriodEndsAt = now.plus(GRACE_PERIOD_DAYS, ChronoUnit.DAYS);
        subscription.markPastDue(now, gracePeriodEndsAt);
        subscriptionRepository.save(subscription);
        eventPublisher.publishEvent(new SubscriptionPaymentFailedEvent(subscription.getId(),
                subscription.getOwnerUserId(), subscription.getGracePeriodEndsAt()));
    }
}
