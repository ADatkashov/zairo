package com.zairo.factory.subscriptions;

import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import java.time.Clock;
import java.util.Optional;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Where a subscription's card (recurring profile) is stored, shown and
 * removed. The actual charge of that profile is {@code
 * PaymentProvider.chargeRecurring}; this class only keeps the bookkeeping,
 * and only ever keeps the last four digits of a card.
 *
 * <p>Removing a card here is <b>local</b>: the provider-side profile is not
 * revoked, because Freedom Pay's profile-deletion request is not confirmed
 * (see ADR-0006). Without a stored profile id the platform can no longer
 * charge it, which is what the owner asked for.
 */
@Service
public class SubscriptionPaymentMethodService {

    private final SubscriptionPaymentMethodRepository repository;
    private final SubscriptionRepository subscriptionRepository;
    private final PaymentProvider paymentProvider;
    private final PaymentProviderName providerName;
    private final Clock clock;

    public SubscriptionPaymentMethodService(SubscriptionPaymentMethodRepository repository,
            SubscriptionRepository subscriptionRepository, PaymentProvider paymentProvider,
            @Value("${payment.provider:mock}") String providerName, Clock clock) {
        this.repository = repository;
        this.subscriptionRepository = subscriptionRepository;
        this.paymentProvider = paymentProvider;
        this.providerName = PaymentProviderName.valueOf(providerName.toUpperCase());
        this.clock = clock;
    }

    /** Remembers the card a successful checkout produced. A null profile id (a provider that sent none) changes nothing. */
    @Transactional
    public void save(UUID subscriptionId, String recurringProfileId, String cardPanOrLast4, String cardBrand) {
        if (recurringProfileId == null || recurringProfileId.isBlank()) {
            return;
        }
        String last4 = last4(cardPanOrLast4);
        String brand = brand(cardBrand);
        var now = clock.instant();
        SubscriptionPaymentMethod existing = repository.findById(subscriptionId).orElse(null);
        if (existing == null) {
            repository.save(new SubscriptionPaymentMethod(subscriptionId, providerName, recurringProfileId, last4,
                    brand, now));
        } else {
            existing.replaceWith(providerName, recurringProfileId, last4, brand, now);
            repository.save(existing);
        }
    }

    public Optional<SubscriptionPaymentMethod> find(UUID subscriptionId) {
        return repository.findById(subscriptionId);
    }

    @Transactional
    public void remove(UUID subscriptionId) {
        repository.deleteById(subscriptionId);
    }

    /** Auto-renewal really happens only if the provider can charge a stored profile, one is stored, and the plan will continue. */
    public boolean autoRenewActive(Subscription subscription, boolean hasPaymentMethod) {
        return paymentProvider.supportsRecurringCharge() && hasPaymentMethod
                && subscription.getPlan() == SubscriptionPlan.PRO && !subscription.isCancelAtPeriodEnd();
    }

    /** Keeps only the last four digits of whatever the provider reported (a masked PAN like {@code 4242 42** **** 4242}). */
    static String last4(String panOrLast4) {
        if (panOrLast4 == null) {
            return null;
        }
        String digits = panOrLast4.replaceAll("\\D", "");
        if (digits.length() < 4) {
            return null;
        }
        return digits.substring(digits.length() - 4);
    }

    private static String brand(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String cleaned = raw.trim().toUpperCase().replaceAll("[^A-Z ]", "");
        return cleaned.isBlank() ? null : cleaned.substring(0, Math.min(cleaned.length(), 20));
    }
}
