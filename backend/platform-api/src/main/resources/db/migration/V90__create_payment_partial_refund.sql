-- Money returned to the customer while the payment itself stays SUCCEEDED: the booking moved to a cheaper worker and
-- the customer had already paid more than the new price. The payment's allocation row stays the historical record;
-- the business payout is reduced by (amount - platform_fee_returned).
create table payment_partial_refund (
    id uuid primary key,
    payment_id uuid not null references payment (id),
    booking_id uuid not null,
    amount numeric(19, 2) not null check (amount > 0),
    currency varchar(3) not null,
    platform_fee_returned numeric(19, 2) not null,
    status varchar(16) not null,
    attempts integer not null default 0,
    last_error varchar(1000),
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index idx_payment_partial_refund_payment_id on payment_partial_refund (payment_id);
create index idx_payment_partial_refund_status on payment_partial_refund (status);
