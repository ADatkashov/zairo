package com.zairo.factory.paymentprovider;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Port to an external payment provider — {@link MockPaymentProvider} (local/
 * test) and {@link com.zairo.factory.paymentprovider.freedompay.FreedomPayProvider}
 * (staging/production) are the two implementations, selected by
 * {@code payment.provider} config (see application.yml). See
 * {@code docs/adr/0006-payment-provider-freedompay.md} for the full design
 * this interface's shape comes from — this doc comment only covers what a
 * caller needs to know, not the reasoning.
 *
 * <p><b>This is redirect/webhook-shaped, not synchronous request/response.</b>
 * {@link #createPayment} and {@link #createRecurringPayment} return a
 * {@link PaymentInitiation} that may already be terminal ({@link
 * InitiationStatus#SUCCEEDED}/{@link InitiationStatus#FAILED} — what
 * {@link MockPaymentProvider} always returns, synchronously, exactly
 * matching this project's pre-Freedom-Pay behavior) or still {@link
 * InitiationStatus#PENDING} with a {@code checkoutUrl} the customer must be
 * redirected to — a real provider's actual confirmation arrives later via
 * its webhook, not from this call's return value. Callers (see
 * {@code payments.PaymentsService}, {@code subscriptions.SubscriptionService})
 * must handle both cases; never assume PENDING can't happen just because
 * today's only caller is the mock.
 *
 * <p><b>Recurring charges are a separate, narrower capability</b> — {@link
 * #chargeRecurring} is what a monthly subscription renewal calls, charging
 * a profile established earlier by {@link #createRecurringPayment} without
 * the customer present. Freedom Pay's exact request shape for this is
 * unconfirmed by public documentation (ADR-0006, Open Questions #1) — an
 * implementation that can't do this yet must throw {@link
 * UnsupportedRecurringChargeException} rather than pretend to succeed; see
 * {@code freedompay.FreedomPayProvider}'s own doc comment.
 *
 * <p><b>Idempotency:</b> {@code paymentId} is the idempotency key for {@link
 * #createPayment}/{@link #createRecurringPayment} — a real implementation
 * forwards it to the provider (Freedom Pay's {@code pg_idempotency_key}) so
 * a retried call is provider-side-safe. This is deliberately not the only
 * idempotency guard: {@code PaymentsService.createPayment} also guards on
 * its own side (never re-initiates a payment that's already PENDING with a
 * checkout URL already issued) precisely because the provider-side
 * guarantee's exact semantics aren't confirmed either (ADR-0006, Open
 * Questions #5) — see that method's own doc comment.
 */
public interface PaymentProvider {

    /**
     * One-off payment (a booking charge). {@code description} /
     * {@code successUrl} / {@code failureUrl} are only meaningful to a
     * redirect-based provider — the mock ignores them.
     */
    PaymentInitiation createPayment(UUID paymentId, BigDecimal amount, String currency, String description,
            String successUrl, String failureUrl);

    /**
     * Same shape as {@link #createPayment}, but also establishes a
     * reusable recurring profile for later {@link #chargeRecurring} calls —
     * this is the subscription-upgrade path (the *first* PRO payment),
     * distinct from a monthly renewal. Separate method rather than a flag
     * on {@link #createPayment} so "can this provider even do recurring"
     * is a real, checkable capability rather than an assumed side effect.
     */
    PaymentInitiation createRecurringPayment(UUID paymentId, BigDecimal amount, String currency, String description,
            String successUrl, String failureUrl);

    /**
     * Charges an existing recurring profile with no customer present (the
     * monthly renewal case). See the interface doc comment and {@link
     * UnsupportedRecurringChargeException} — an implementation unable to
     * confirm this operation's real request shape must throw rather than
     * guess.
     */
    ChargeResult chargeRecurring(String recurringProfileId, UUID paymentId, BigDecimal amount, String currency);

    /**
     * Whether {@link #chargeRecurring} actually works for this provider. A
     * provider that cannot (Freedom Pay, until its recurring-charge docs are
     * confirmed) returns {@code false}: the renewal job then does not even
     * try, and asks the owner to renew through the hosted checkout instead —
     * rather than failing every renewal with an exception.
     */
    default boolean supportsRecurringCharge() {
        return true;
    }

    /**
     * Server-to-server status check, independent of the webhook — a
     * reconciliation fallback (ADR-0006, Webhook Architecture), not the
     * primary confirmation path. Not yet called anywhere in this codebase;
     * exists so the port doesn't need another breaking change once
     * reconciliation tooling is built.
     */
    PaymentStatusResult getPaymentStatus(UUID paymentId, String providerPaymentId);

    RefundResult refund(UUID paymentId, String providerPaymentId, BigDecimal amount);

    enum InitiationStatus {
        PENDING, SUCCEEDED, FAILED
    }

    /**
     * {@code cardLast4}/{@code cardBrand} are display-only and nullable —
     * only filled when the provider already knows the card at initiation
     * time (the mock does; a redirect provider reports it later, via its
     * webhook). Never a full card number.
     */
    record PaymentInitiation(String providerPaymentId, String checkoutUrl, String recurringProfileId,
            InitiationStatus status, String failureReason, String cardLast4, String cardBrand) {

        public PaymentInitiation(String providerPaymentId, String checkoutUrl, String recurringProfileId,
                InitiationStatus status, String failureReason) {
            this(providerPaymentId, checkoutUrl, recurringProfileId, status, failureReason, null, null);
        }
    }

    record ChargeResult(boolean succeeded, String providerReference, String failureReason) {
    }

    record PaymentStatusResult(InitiationStatus status, String providerReference) {
    }

    record RefundResult(boolean succeeded, String failureReason) {
    }
}
