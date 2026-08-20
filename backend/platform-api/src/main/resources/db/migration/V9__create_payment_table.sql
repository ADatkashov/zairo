create table payment (
    id uuid primary key,
    booking_id uuid not null unique references booking (id),
    amount numeric(10, 2) not null,
    currency varchar(3) not null,
    status varchar(20) not null,
    provider_reference varchar(255),
    failure_reason varchar(255),
    created_at timestamptz not null,
    updated_at timestamptz not null
);
