-- A staff member who can't attend an appointment does not cancel it (that would refund the customer without the owner's
-- decision); they send the owner a request, recorded here. The booking itself is untouched until the owner acts.
alter table staff_booking add column staff_declined_at timestamptz;
alter table staff_booking add column staff_decline_reason varchar(500);
