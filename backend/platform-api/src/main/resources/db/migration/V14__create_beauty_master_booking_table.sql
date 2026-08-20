create table beauty_master_booking (
    id uuid primary key,
    booking_id uuid not null unique references booking (id),
    master_id uuid not null references beauty_master (id),
    created_at timestamptz not null
);
