package com.zairo.factory.payments;

import java.util.UUID;

/**
 * Published (in-process, same transaction) right after a {@link
 * PaymentRefundRequest} row is written, so {@code
 * PaymentRefundOutboxProcessor} can try it eagerly, right after commit,
 * instead of waiting for its next scheduled sweep -- same "latency
 * optimization for the common case" role as {@code
 * loyalty.LoyaltyOutboxEventReady}. The row itself (not this event) is what
 * guarantees the refund is never lost: this event is just as in-memory/
 * best-effort as the pre-outbox {@code BookingCancelledPaymentListener} used
 * to be entirely.
 */
record PaymentRefundRequestReady(UUID refundRequestId) {
}
