-- Account deletion anonymizes the app_user row instead of removing it (bookings, payments, reviews, messages and
-- the loyalty ledger keep referencing it). deleted_at marks such a row; every personal column is wiped.
alter table app_user add column deleted_at timestamp with time zone;
