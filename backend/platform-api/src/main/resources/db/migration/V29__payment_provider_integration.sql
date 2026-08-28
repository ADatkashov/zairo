-- ADR-0006 (docs/adr/0006-payment-provider-freedompay.md) — real payment
-- provider support. See Payment.java's own field-by-field doc comments for
-- what each column means; not repeated here.

alter table payment add column provider varchar(20);
update payment set provider = 'MOCK' where provider is null;
alter table payment alter column provider set not null;

alter table payment add column idempotency_key uuid;
update payment set idempotency_key = id where idempotency_key is null;
alter table payment alter column idempotency_key set not null;

alter table payment add column provider_status varchar(50);
alter table payment add column checkout_url text;
alter table payment add column refund_attempts integer not null default 0;

-- @Version — every existing row starts at 0, Hibernate's default.
alter table payment add column version integer not null default 0;

-- PaymentStatus gained CREATED/REFUND_PENDING/REFUND_FAILED (varchar column,
-- no constraint to update) — every pre-existing row's actual status value
-- (PENDING/SUCCEEDED/FAILED/REFUNDED) is still a valid member of the
-- widened enum, nothing to backfill there.
