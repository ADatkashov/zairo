-- Marketplace commission split + business settlement — see
-- docs/adr/0007-marketplace-commission-and-settlement.md and
-- docs/PAYMENTS_FREEDOM_PAY.md. Deliberately two tables, not two columns on
-- `payment`: allocation (how a SUCCEEDED payment splits between ZAIRO and
-- the business) and payout (whether/when the business's share was actually
-- paid out) are different facts with different lifecycles — an allocation
-- exists the moment a payment succeeds, a payout only once the booking is
-- COMPLETED (see PaymentAllocation/BusinessPayout's own doc comments).

-- One row per payment that ever succeeded — created once, immutable after
-- (a refund does not delete or rewrite this row; it is a historical fact
-- about what a SUCCEEDED payment was worth, see docs/PAYMENT_STATE_MACHINE.md).
create table payment_allocation (
    payment_id uuid primary key references payment (id),
    business_amount numeric(10, 2) not null,
    platform_fee numeric(10, 2) not null,
    currency varchar(3) not null,
    -- The commission rate actually applied, snapshotted at allocation time —
    -- payment.commission.rate is mutable config; a payout/refund/reconciliation
    -- computed months later must reproduce THIS payment's split, not
    -- whatever the rate happens to be configured as today.
    commission_rate numeric(5, 4) not null,
    created_at timestamptz not null
);

-- One row per booking whose business share is ever payable — created only
-- once BookingCompletedEvent fires (never at payment time: a booking that's
-- refunded/cancelled before completion never gets one). See
-- BusinessPayoutStatus for the status vocabulary.
create table business_payout (
    id uuid primary key,
    booking_id uuid not null unique references booking (id),
    payment_id uuid not null references payment (id),
    provider_id uuid not null references provider (id),
    amount numeric(10, 2) not null,
    currency varchar(3) not null,
    status varchar(20) not null,
    -- Free-text reference to whatever actually moved the money — a manual
    -- bank transfer id today (see ADR-0007: Freedom Pay's own payout-
    -- initiation API isn't confirmed by this integration), a Freedom Pay
    -- G2G payout id if/when that's confirmed and wired in later. Never a
    -- column this module validates the shape of.
    provider_reference varchar(255),
    failure_reason varchar(255),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    settled_at timestamptz,
    version integer not null default 0
);

create index idx_business_payout_provider_id on business_payout (provider_id);
create index idx_business_payout_status on business_payout (status);
