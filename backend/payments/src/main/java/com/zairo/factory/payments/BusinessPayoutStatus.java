package com.zairo.factory.payments;

/**
 * A {@link BusinessPayout}'s own state machine — deliberately separate from
 * {@link PaymentStatus} (see docs/adr/0007's "don't collapse Payment and
 * Settlement into one status variable", itself following the task's own
 * "не смешивай Payment и Booking в одну простую status-переменную"
 * principle, extended to settlement).
 */
public enum BusinessPayoutStatus {
    /** Booking COMPLETED, payment SUCCEEDED, nothing paid out yet. */
    PAYABLE,
    /** A platform admin has started moving the money (see ADR-0007 — manual bank transfer today, not a Freedom Pay API call). */
    PROCESSING,
    /** Terminal — the business has actually received the money. */
    PAID,
    /** The most recent attempt failed — retriable, same "not silently lost" principle as Payment.REFUND_FAILED. */
    FAILED
}
