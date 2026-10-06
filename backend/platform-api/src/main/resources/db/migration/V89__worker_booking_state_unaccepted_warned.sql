-- When the owner was warned that the worker hasn't accepted an upcoming appointment (once per appointment).
alter table worker_booking_state add column unaccepted_warned_at timestamptz;
