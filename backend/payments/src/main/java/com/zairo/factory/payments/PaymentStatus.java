package com.zairo.factory.payments;

public enum PaymentStatus {
    /** Row exists, provider not yet successfully contacted (or the attempt errored before a result came back). */
    CREATED,
    /** Provider accepted the payment (checkout URL issued for a real provider); final outcome awaits a webhook. */
    PENDING,
    SUCCEEDED,
    FAILED,
    /**
     * A durable {@link PaymentRefundRequest} exists for this payment and
     * hasn't resolved yet — set as soon as the request row is created
     * (atomically with the booking-cancellation or already-cancelled-
     * booking-webhook write that caused it), cleared to REFUNDED or
     * REFUND_FAILED once {@code PaymentRefundOutboxProcessor} resolves it.
     * Originally defined for completeness only (ADR-0006's Payment State
     * Machine noted Freedom Pay's {@code /revoke} appears to be synchronous
     * request/response, not webhook-confirmed) — now genuinely reachable via
     * the durable refund outbox (see ADR-0006's "Durable Refund Outbox"
     * section), independently of whether the provider call itself is sync
     * or webhook-confirmed.
     */
    REFUND_PENDING,
    REFUNDED,
    REFUND_FAILED
}
