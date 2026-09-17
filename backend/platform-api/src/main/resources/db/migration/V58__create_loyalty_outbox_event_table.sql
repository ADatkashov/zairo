-- Durability for loyalty earning (Phase 0 stabilization): before this
-- table, LoyaltyEarningListener ran purely in-memory via
-- @TransactionalEventListener(AFTER_COMMIT) -- a crash between the booking
-- (or review) commit and that listener firing lost the earning forever,
-- with no retry. Now the listener's own job is reduced to writing one row
-- here, in the SAME transaction as the booking/review write it reacts to
-- (a plain @EventListener, not AFTER_COMMIT -- see LoyaltyEarningListener),
-- so the outbox row is as durable as the event that caused it. A separate
-- scheduled job (LoyaltyOutboxProcessor) then does the actual earning
-- computation in its own transaction, retrying PENDING rows until they
-- succeed -- safe to retry because LoyaltyLedgerService#earn is already
-- idempotent per (referenceType, referenceId) (V57's partial unique
-- indexes on loyalty_transaction).
create table loyalty_outbox_event (
    id uuid primary key,
    event_type varchar(30) not null,
    provider_id uuid not null,
    user_id uuid not null,
    booking_id uuid not null,
    review_id uuid,
    status varchar(20) not null default 'PENDING',
    attempts int not null default 0,
    last_error varchar(1000),
    created_at timestamptz not null,
    processed_at timestamptz
);

-- LoyaltyOutboxProcessor's polling query: oldest-first, only PENDING rows.
create index idx_loyalty_outbox_event_status_created_at on loyalty_outbox_event (status, created_at)
    where status = 'PENDING';
