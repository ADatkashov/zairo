-- Nullable — set when a refund attempt fails, cleared on a subsequent
-- success. Before this, a failed refund was only ever visible in the
-- server log (see BookingCancelledPaymentListener's catch block) —
-- durably recording it here means "still SUCCEEDED with a non-null
-- refund_failure_reason" is a queryable fact, not something only a human
-- reading logs at the right moment would ever see.
alter table payment add column refund_failure_reason text;
