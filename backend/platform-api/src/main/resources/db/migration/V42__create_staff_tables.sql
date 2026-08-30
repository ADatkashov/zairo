create table staff (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    display_name varchar(255) not null,
    bio text,
    photo_url varchar(500),
    is_active boolean not null default true,
    created_at timestamptz not null
);

create index idx_staff_provider_id on staff (provider_id);

create table staff_service (
    id uuid primary key,
    staff_id uuid not null references staff (id),
    service_id uuid not null references service (id),
    unique (staff_id, service_id)
);

create index idx_staff_service_staff_id on staff_service (staff_id);

create table staff_booking (
    id uuid primary key,
    booking_id uuid not null unique references booking (id),
    staff_id uuid not null references staff (id),
    created_at timestamptz not null
);
