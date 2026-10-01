-- Durable, retryable refund workflow for a cancelled paid Booking --
-- mirrors V58's loyalty_outbox_event pattern, applied to money movement
-- instead of points. Before this table, BookingCancelledPaymentListener
-- refunded a cancelled booking's payment best-effort, AFTER_COMMIT +
-- REQUIRES_NEW: a crash, a transient Freedom Pay outage, or any
-- RuntimeException from PaymentsService#refundPayment left the refund
-- permanently lost, with no retry (see that class's old doc comment). Now
-- the listener's job is reduced to writing one row here, in the SAME
-- transaction as the booking-cancellation write (or the already-cancelled-
-- booking webhook transition) that requires it -- a plain @EventListener,
-- not AFTER_COMMIT -- so the refund intent is as durable as the fact that
-- caused it. PaymentRefundOutboxProcessor does the actual provider call,
-- outside any database transaction, retrying with backoff up to
-- PaymentRefundRequest.MAX_ATTEMPTS before dead-lettering to FAILED.
--
-- payment_id/booking_id reference payment/booking directly (not the bare-
-- uuid-no-FK convention newer modules use) because this table lives in the
-- payments module, which already has a direct Gradle dependency on booking
-- and obviously owns payment -- same convention V9's own payment table
-- already uses for booking_id.
create table payment_refund_request (
    id uuid primary key,
    payment_id uuid not null unique references payment (id),
    booking_id uuid not null references booking (id),
    amount numeric(10, 2) not null,
    currency varchar(3) not null,
    provider varchar(20) not null,
    provider_reference varchar(255) not null,
    status varchar(20) not null default 'PENDING',
    attempts int not null default 0,
    next_attempt_at timestamptz,
    processing_started_at timestamptz,
    last_error varchar(1000),
    created_at timestamptz not null,
    updated_at timestamptz not null
);

-- PaymentRefundOutboxProcessor's sweep query (PaymentRefundRequestRepository#findDue):
-- due PENDING/RETRY rows, oldest first.
create index idx_payment_refund_request_due on payment_refund_request (next_attempt_at)
    where status in ('PENDING', 'RETRY');

-- The same sweep's other half: PROCESSING rows old enough to be a crashed
-- worker's leftovers (restart recovery -- see PaymentRefundRequest#isClaimable).
create index idx_payment_refund_request_processing on payment_refund_request (processing_started_at)
    where status = 'PROCESSING';

-- The platform admin's refund-outbox visibility list (failed/in-flight refunds).
create index idx_payment_refund_request_status_created_at on payment_refund_request (status, created_at);
