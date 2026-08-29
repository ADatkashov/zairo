create table cleaning_booking (
    id uuid primary key,
    booking_id uuid not null unique references booking (id),
    cleaner_id uuid not null references cleaning_cleaner (id),
    created_at timestamptz not null
);
