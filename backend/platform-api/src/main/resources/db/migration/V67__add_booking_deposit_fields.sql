-- Add deposit-related fields to booking to capture the payment policy at booking creation time
-- These fields are immutable after creation and represent the policy that was in effect
-- when the booking was created

alter table booking
add column deposit_type varchar(20) default 'NO_PAYMENT' not null,
add column deposit_value_type varchar(20),
add column deposit_value numeric(10, 2),
add column deposit_amount numeric(10, 2),
add column paid_amount numeric(10, 2) not null default 0,
add column remaining_amount numeric(10, 2);

-- The remaining_amount is calculated based on totalPrice, depositAmount, and paidAmount
-- remaining_amount = totalPrice - paidAmount
-- We need to recalculate it for existing rows during deployment
update booking set remaining_amount = total_price;

-- Make remaining_amount NOT NULL after backfilling
alter table booking alter column remaining_amount set not null;

-- Add an index for queries filtering by deposit_type
create index idx_booking_deposit_type on booking (deposit_type);

-- Add index for tracking payment status across bookings
create index idx_booking_remaining_amount on booking (remaining_amount);
