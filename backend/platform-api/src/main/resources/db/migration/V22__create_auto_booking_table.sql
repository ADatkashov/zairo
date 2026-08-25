create table auto_booking (
    id uuid primary key,
    booking_id uuid not null unique references booking (id),
    mechanic_id uuid not null references auto_mechanic (id),
    vehicle_id uuid not null references auto_vehicle (id),
    created_at timestamptz not null
);
