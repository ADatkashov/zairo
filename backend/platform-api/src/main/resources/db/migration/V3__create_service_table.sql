create table service (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    title varchar(255) not null,
    duration_minutes integer not null,
    price numeric(10, 2) not null,
    currency varchar(3) not null,
    is_active boolean not null
);

create index idx_service_provider_id on service (provider_id);
