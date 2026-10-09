-- One row of "what the worker and the owner said about this booking", for all four worker directories
-- (staff / beauty master / auto mechanic / cleaner) instead of columns on each booking-link table.
create table worker_booking_state (
    booking_id uuid primary key references booking (id),
    worker_id uuid not null,
    confirmed_at timestamptz,
    declined_at timestamptz,
    decline_reason varchar(500),
    preference varchar(16) not null default 'SPECIFIC',
    created_at timestamptz not null
);

create index idx_worker_booking_state_worker_id on worker_booking_state (worker_id);

-- Acceptances already recorded on staff_booking (V84) move over; the column is then redundant.
insert into worker_booking_state (booking_id, worker_id, confirmed_at, preference, created_at)
select booking_id, staff_id, staff_confirmed_at, 'SPECIFIC', staff_confirmed_at
from staff_booking
where staff_confirmed_at is not null;

alter table staff_booking drop column staff_confirmed_at;
