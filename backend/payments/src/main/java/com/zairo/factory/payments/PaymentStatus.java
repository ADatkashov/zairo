package com.zairo.factory.payments;

public enum PaymentStatus {
    /** Row exists, provider not yet successfully contacted (or the attempt errored before a result came back). */
    CREATED,
    /** Provider accepted the payment (checkout URL issued for a real provider); final outcome awaits a webhook. */
    PENDING,
    SUCCEEDED,
    FAILED,
    /**
     * Defined for completeness (ADR-0006's Payment State Machine) but not
     * currently reachable — Freedom Pay's {@code /revoke} appears to be a
     * synchronous request/response, not webhook-confirmed (unconfirmed,
     * see ADR-0006 Open Questions #3). Keeping the state avoids a second
     * migration if refund turns out to be async after all.
     */
    REFUND_PENDING,
    REFUNDED,
    REFUND_FAILED
}
