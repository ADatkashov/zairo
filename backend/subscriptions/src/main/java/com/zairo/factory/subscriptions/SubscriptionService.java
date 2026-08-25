package com.zairo.factory.subscriptions;

import com.zairo.factory.paymentprovider.PaymentProvider;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Every owner implicitly has a subscription — {@link #getOrCreate} is the
 * one place that laziness lives, mirroring how {@code Provider} always
 * starts PENDING rather than every caller special-casing "no row yet".
 */
@Service
public class SubscriptionService {

    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionChargeRepository subscriptionChargeRepository;
    private final PaymentProvider paymentProvider;
    private final String defaultCurrency;

    public SubscriptionService(SubscriptionRepository subscriptionRepository,
            SubscriptionChargeRepository subscriptionChargeRepository, PaymentProvider paymentProvider,
            @Value("${app.platform.default-currency:USD}") String defaultCurrency) {
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionChargeRepository = subscriptionChargeRepository;
        this.paymentProvider = paymentProvider;
        this.defaultCurrency = defaultCurrency;
    }

    @Transactional
    public Subscription getOrCreate(UUID ownerUserId) {
        return subscriptionRepository.findByOwnerUserId(ownerUserId)
                .orElseGet(() -> subscriptionRepository.save(new Subscription(UUID.randomUUID(), ownerUserId,
                        Instant.now())));
    }

    /**
     * Already-PRO is treated as "undo a pending downgrade" (idempotent, no
     * re-charge) rather than an error — the natural action for someone who
     * clicks Upgrade again after having clicked Downgrade earlier in the
     * same period.
     */
    @Transactional
    public Subscription upgradeToPro(UUID ownerUserId) {
        Subscription subscription = getOrCreate(ownerUserId);
        if (subscription.getPlan() == SubscriptionPlan.PRO) {
            subscription.clearDowngradeRequest(Instant.now());
            return subscriptionRepository.save(subscription);
        }

        SubscriptionCharge charge = subscriptionChargeRepository.save(new SubscriptionCharge(UUID.randomUUID(),
                subscription.getId(), SubscriptionPlan.PRO.monthlyPrice, defaultCurrency, Instant.now()));
        PaymentProvider.ChargeResult result;
        try {
            result = paymentProvider.charge(charge.getId(), charge.getAmount(), charge.getCurrency());
        } catch (RuntimeException e) {
            charge.markFailed("Payment provider error: " + e.getMessage(), Instant.now());
            subscriptionChargeRepository.save(charge);
            throw new SubscriptionUpgradeFailedException("Could not charge for the PRO plan: " + e.getMessage());
        }
        if (!result.succeeded()) {
            charge.markFailed(result.failureReason(), Instant.now());
            subscriptionChargeRepository.save(charge);
            throw new SubscriptionUpgradeFailedException("Payment declined: " + result.failureReason());
        }
        charge.markSucceeded(result.providerReference(), Instant.now());
        subscriptionChargeRepository.save(charge);

        subscription.markUpgradedToPro(Instant.now());
        return subscriptionRepository.save(subscription);
    }

    /**
     * Self-service, takes effect at the end of the current paid period — no
     * proration, no refund of the period already paid for (see the
     * subscriptions ADR / SESSION_NOTES.md for why this is out of scope for
     * the first pass). A FREE owner has nothing to downgrade from — no-op.
     */
    @Transactional
    public Subscription downgradeToFreeAtPeriodEnd(UUID ownerUserId) {
        Subscription subscription = getOrCreate(ownerUserId);
        subscription.requestDowngradeAtPeriodEnd(Instant.now());
        return subscriptionRepository.save(subscription);
    }
}
