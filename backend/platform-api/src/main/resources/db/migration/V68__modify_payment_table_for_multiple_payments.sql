-- Modify payment table to support multiple payments per booking
-- and track the payment method used

-- Step 1: Drop the existing unique constraint on booking_id (allow multiple payments per booking)
alter table payment drop constraint payment_booking_id_key;

-- Step 2: Add payment_method column with default ONLINE for backward compatibility
alter table payment
add column payment_method varchar(20) not null default 'ONLINE';

-- Step 3: Add provider_status column if it doesn't exist (for audit)
-- Note: This column might already exist, so we add it conditionally
-- by checking if the migration was partially applied
do $$
begin
    if not exists(select 1 from information_schema.columns
                  where table_name='payment' and column_name='provider_status') then
        alter table payment add column provider_status varchar(255);
    end if;
end $$;

-- Step 4: Create a regular (non-unique) index on booking_id for efficient queries
create index idx_payment_booking_id on payment (booking_id);

-- Step 5: Create index for querying payments by method
create index idx_payment_method on payment (payment_method);

-- Step 6: Create composite index for common queries
create index idx_payment_booking_status on payment (booking_id, status);
