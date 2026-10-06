-- A staff member acknowledges ("accepts") an appointment booked with them from their own cabinet.
-- Null until they do; the booking's own status is untouched (it is CONFIRMED by the payment flow).
alter table staff_booking add column staff_confirmed_at timestamptz;
