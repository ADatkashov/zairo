package com.zairo.factory.paymentprovider;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Port to an external payment provider (Stripe, etc.) — {@link
 * MockPaymentProvider} is the only implementation for now, since real
 * integration needs a provider account and API keys that don't exist yet
 * (see ADR candidate: swap in a real provider once test-mode credentials
 * are available). Shaped loosely after Stripe's PaymentIntent/Refund
 * model so a future real implementation is a drop-in swap, not a redesign.
 *
 * <p>Two callers today: {@code payments.PaymentsService} (one-off booking
 * charges) and {@code subscriptions.SubscriptionRenewalService}/
 * {@code SubscriptionService} (recurring plan charges) — this is why the
 * port lives in its own dependency-free module rather than inside
 * {@code payments} itself: {@code subscriptions} needed the same port
 * without pulling in {@code payments}' own dependency on {@code booking}
 * (which would have created a cycle back through {@code providers}).
 *
 * <p>Per this module's package-info ("webhook is the source of truth, never
 * the client"): a real implementation would make {@link #charge} return
 * immediately with a pending/requires-action result and rely on an
 * incoming webhook to confirm success asynchronously. The mock instead
 * resolves synchronously, since there's no real async gateway to wait on
 * yet — the webhook-driven confirmation flow is deferred until a real
 * provider exists, not built against nothing.
 *
 * <p><b>Idempotency:</b> {@code paymentId} is the idempotency key. A real
 * implementation must forward it unchanged to the provider (e.g. Stripe's
 * {@code idempotencyKey} request option on both charge and refund calls)
 * so that a retried call with the same id is a safe no-op on the
 * provider's side rather than a second charge/refund — this only holds
 * if the caller reuses the same persisted row across retries instead of
 * minting a fresh id each attempt; see {@code payments.PaymentsService
 * .createPayment}'s and {@code subscriptions.SubscriptionRenewalService
 * .chargeForRenewal}'s retry-reuses-the-existing-row logic for why that
 * matters.
 */
public interface PaymentProvider {

    ChargeResult charge(UUID paymentId, BigDecimal amount, String currency);

    RefundResult refund(UUID paymentId, String providerReference, BigDecimal amount);

    record ChargeResult(boolean succeeded, String providerReference, String failureReason) {
    }

    record RefundResult(boolean succeeded, String failureReason) {
    }
}
