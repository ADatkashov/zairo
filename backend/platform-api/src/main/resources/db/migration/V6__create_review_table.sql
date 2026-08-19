create table review (
    id uuid primary key,
    booking_id uuid not null unique references booking (id),
    rating integer not null check (rating between 1 and 5),
    comment text,
    created_at timestamptz not null
);
