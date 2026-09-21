package com.zairo.factory.payments;

/** Lifecycle of one {@link PaymentRefundRequest} row -- see that class's own doc comment. */
public enum PaymentRefundRequestStatus {
    /** Never attempted yet. */
    PENDING,
    /** Claimed by a worker; the provider call is in flight (or the worker crashed mid-call -- see isClaimable). */
    PROCESSING,
    /** At least one attempt failed and wasn't permanent -- waiting for nextAttemptAt before the next try. */
    RETRY,
    /** Terminal: the provider confirmed the refund. Never revisited by the worker again. */
    SUCCEEDED,
    /** Terminal: gave up after {@link PaymentRefundRequest#MAX_ATTEMPTS} failed attempts -- needs human attention. */
    FAILED
}
