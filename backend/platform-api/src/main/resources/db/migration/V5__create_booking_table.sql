create table booking (
    id uuid primary key,
    user_id uuid not null references app_user (id),
    service_id uuid not null references service (id),
    availability_slot_id uuid not null references availability_slot (id),
    status varchar(20) not null,
    total_price numeric(10, 2) not null,
    created_at timestamptz not null
);

create index idx_booking_user_id on booking (user_id);
create unique index idx_booking_availability_slot_id on booking (availability_slot_id);
