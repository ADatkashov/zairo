package com.zairo.factory.subscriptions;

import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.paymentprovider.PaymentProvider.InitiationStatus;
import com.zairo.factory.paymentprovider.PaymentProvider.PaymentInitiation;
import com.zairo.factory.paymentprovider.PaymentProviderName;
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
    private final PaymentProviderName providerName;
    private final String defaultCurrency;
    private final String successUrl;
    private final String failureUrl;

    public SubscriptionService(SubscriptionRepository subscriptionRepository,
            SubscriptionChargeRepository subscriptionChargeRepository, PaymentProvider paymentProvider,
            @Value("${payment.provider:mock}") String providerName,
            @Value("${app.platform.default-currency:USD}") String defaultCurrency,
            @Value("${payment.return.success-url:}") String successUrl,
            @Value("${payment.return.failure-url:}") String failureUrl) {
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionChargeRepository = subscriptionChargeRepository;
        this.paymentProvider = paymentProvider;
        this.providerName = PaymentProviderName.valueOf(providerName.toUpperCase());
        this.defaultCurrency = defaultCurrency;
        this.successUrl = successUrl;
        this.failureUrl = failureUrl;
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
     *
     * <p>Under the mock provider this resolves synchronously and {@code
     * checkoutUrl} on the result is always null, exactly matching this
     * codebase's pre-Freedom-Pay behavior. Under a real redirect-based
     * provider the subscription is <b>not</b> upgraded yet when this
     * returns — the caller must send the customer to {@code checkoutUrl}
     * and the actual upgrade happens once the provider's webhook confirms
     * the charge (see the webhook processor) — same "frontend redirect is
     * not the source of truth" rule as booking payments (ADR-0006).
     */
    @Transactional
    public SubscriptionUpgradeResult upgradeToPro(UUID ownerUserId) {
        Subscription subscription = getOrCreate(ownerUserId);
        if (subscription.getPlan() == SubscriptionPlan.PRO) {
            subscription.clearDowngradeRequest(Instant.now());
            return new SubscriptionUpgradeResult(subscriptionRepository.save(subscription), null);
        }

        SubscriptionCharge charge = subscriptionChargeRepository.save(new SubscriptionCharge(UUID.randomUUID(),
                subscription.getId(), SubscriptionPlan.PRO.monthlyPrice, defaultCurrency, providerName, null,
                Instant.now()));

        PaymentInitiation result;
        try {
            result = paymentProvider.createRecurringPayment(charge.getId(), charge.getAmount(), charge.getCurrency(),
                    "Factory PRO subscription", successUrl, failureUrl);
        } catch (RuntimeException e) {
            charge.markFailed("Payment provider error: " + e.getMessage(), Instant.now());
            subscriptionChargeRepository.save(charge);
            throw new SubscriptionUpgradeFailedException("Could not charge for the PRO plan: " + e.getMessage());
        }

        if (result.recurringProfileId() != null) {
            charge.assignRecurringProfileId(result.recurringProfileId(), Instant.now());
        }

        if (result.status() == InitiationStatus.FAILED) {
            charge.markFailed(result.failureReason(), Instant.now());
            subscriptionChargeRepository.save(charge);
            throw new SubscriptionUpgradeFailedException("Payment declined: " + result.failureReason());
        }

        if (result.status() == InitiationStatus.PENDING) {
            subscriptionChargeRepository.save(charge);
            return new SubscriptionUpgradeResult(subscription, result.checkoutUrl());
        }

        charge.markSucceeded(result.providerPaymentId(), Instant.now());
        subscriptionChargeRepository.save(charge);
        subscription.markUpgradedToPro(Instant.now());
        return new SubscriptionUpgradeResult(subscriptionRepository.save(subscription), null);
    }

    /** {@code checkoutUrl} is non-null only when a real provider left the charge PENDING — see {@link #upgradeToPro}. */
    public record SubscriptionUpgradeResult(Subscription subscription, String checkoutUrl) {
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
