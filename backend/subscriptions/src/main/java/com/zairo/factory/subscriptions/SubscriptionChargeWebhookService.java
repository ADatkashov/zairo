package com.zairo.factory.subscriptions;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The subscription side of Freedom Pay webhook confirmation (Phase 0
 * stabilization) — the counterpart to {@code payments.PaymentWebhookProcessor}
 * for booking payments, kept in its own module/service rather than folded
 * into that class: a subscription-charge webhook and a booking-payment
 * webhook resolve to different tables, different state machines (a {@code
 * SubscriptionCharge} confirms a {@link Subscription} plan transition, a
 * {@code Payment} confirms a {@code Booking} status transition), and
 * different ownership/ correction rules — sharing one service would mean
 * an {@code if (isSubscription)} branch threaded through otherwise-unrelated
 * logic. {@code payments.PaymentWebhookProcessor} only ever calls into this
 * class's one public entry point, {@link #applyChargeResult}, after its own
 * signature verification and {@code (provider, eventId)} duplicate-webhook
 * check already ran — this class only ever sees an already-authenticated,
 * already-deduplicated webhook.
 *
 * <p>Before this class existed, a subscription-upgrade charge's webhook was
 * misrouted into {@code payments.PaymentRepository} (a {@code
 * SubscriptionCharge} id looked up in the booking-payments table) and
 * always came back empty — a real-provider PRO upgrade could never actually
 * activate. See {@code FreedomPayOrderIds}' own doc comment for the full
 * "why".
 */
@Service
public class SubscriptionChargeWebhookService {

    /** What {@code PaymentWebhookProcessor} should do with the webhook after this class has looked at it. */
    public enum Outcome {
        /** The charge succeeded and (for a still-FREE subscription) PRO was activated, or failure was recorded. */
        APPLIED,
        /** This exact charge was already SUCCEEDED/FAILED — a duplicate/retried webhook, safe no-op. */
        ALREADY_RESOLVED,
        /** No {@link SubscriptionCharge} exists for the id embedded in the webhook's order id. */
        UNKNOWN_CHARGE,
        /** The webhook's amount/currency doesn't match what this charge was created for. */
        AMOUNT_MISMATCH
    }

    private final SubscriptionChargeRepository chargeRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final Clock clock;

    public SubscriptionChargeWebhookService(SubscriptionChargeRepository chargeRepository,
            SubscriptionRepository subscriptionRepository, Clock clock) {
        this.chargeRepository = chargeRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.clock = clock;
    }

    /**
     * Applies one webhook's outcome to the {@link SubscriptionCharge} it
     * names. Idempotent: a charge not still PENDING is left untouched and
     * reported as {@link Outcome#ALREADY_RESOLVED} — a retried webhook (the
     * caller's own {@code (provider, eventId)} table would normally already
     * catch this, but a genuinely distinct redelivery with a new event id
     * for an already-resolved charge must still never re-activate/re-fail
     * PRO a second time).
     */
    @Transactional
    public Outcome applyChargeResult(UUID chargeId, boolean succeeded, String providerReference,
            BigDecimal webhookAmount, String webhookCurrency, String failureReason) {
        SubscriptionCharge charge = chargeRepository.findById(chargeId).orElse(null);
        if (charge == null) {
            return Outcome.UNKNOWN_CHARGE;
        }
        if (charge.getStatus() != SubscriptionChargeStatus.PENDING) {
            return Outcome.ALREADY_RESOLVED;
        }
        if (!amountAndCurrencyMatch(charge, webhookAmount, webhookCurrency)) {
            return Outcome.AMOUNT_MISMATCH;
        }

        Instant now = clock.instant();
        if (!succeeded) {
            charge.markFailed(failureReason == null ? "Freedom Pay reported failure" : failureReason, now);
            chargeRepository.save(charge);
            // Subscription plan is simply never touched here -- it stays
            // exactly what it was (FREE, or PRO if this was a renewal
            // charge that failed) -- no separate "undo" step needed.
            return Outcome.APPLIED;
        }

        charge.markSucceeded(providerReference, now);
        chargeRepository.save(charge);

        Subscription subscription = subscriptionRepository.findById(charge.getSubscriptionId()).orElse(null);
        if (subscription != null && subscription.getPlan() != SubscriptionPlan.PRO) {
            subscription.markUpgradedToPro(now);
            subscriptionRepository.save(subscription);
        }
        return Outcome.APPLIED;
    }

    /** Read-only: lets {@code payments.PaymentWebhookProcessor} decide whether an order id even names a known charge. */
    public boolean exists(UUID chargeId) {
        return chargeRepository.existsById(chargeId);
    }

    private static boolean amountAndCurrencyMatch(SubscriptionCharge charge, BigDecimal webhookAmount,
            String webhookCurrency) {
        if (webhookAmount != null && webhookAmount.compareTo(charge.getAmount()) != 0) {
            return false;
        }
        return webhookCurrency == null || webhookCurrency.equalsIgnoreCase(charge.getCurrency());
    }
}
