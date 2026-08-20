package com.zairo.factory.payments;

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
 * Per this module's package-info ("webhook is the source of truth, never
 * the client"): a real implementation would make {@link #charge} return
 * immediately with a pending/requires-action result and rely on an
 * incoming webhook to confirm success asynchronously. The mock instead
 * resolves synchronously, since there's no real async gateway to wait on
 * yet — the webhook-driven confirmation flow is deferred until a real
 * provider exists, not built against nothing.
 */
public interface PaymentProvider {

    ChargeResult charge(UUID paymentId, BigDecimal amount, String currency);

    RefundResult refund(String providerReference, BigDecimal amount);

    record ChargeResult(boolean succeeded, String providerReference, String failureReason) {
    }

    record RefundResult(boolean succeeded, String failureReason) {
    }
}
