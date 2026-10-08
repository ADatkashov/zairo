-- Marketplace commission rates, editable by PLATFORM_ADMIN at runtime (replaces
-- the fixed payment.commission.rate config value — see CommissionRateService).
-- One row with category_id NULL is the platform-wide default; a row with a
-- category_id overrides it for every provider whose business type belongs to
-- that category. The rate actually applied to a payment is still snapshotted
-- on payment_allocation.commission_rate, so changing a rate here never
-- rewrites past payments.
create table commission_rate (
    id uuid primary key,
    category_id uuid references category (id),
    -- Fraction of the payment amount, 0..1 (0.1000 = 10%).
    rate numeric(5, 4) not null check (rate >= 0 and rate <= 1),
    updated_at timestamptz not null,
    updated_by varchar(255),
    constraint uq_commission_rate_category unique (category_id)
);

-- NULLs are distinct in a plain unique constraint, so the single default row
-- needs its own guard.
create unique index uq_commission_rate_default on commission_rate ((1)) where category_id is null;

-- No commission until the platform decides to introduce one: default 0%.
insert into commission_rate (id, category_id, rate, updated_at, updated_by)
values ('00000000-0000-0000-0000-000000000c01', null, 0, now(), 'system');
