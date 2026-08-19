create table availability_slot (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    status varchar(20) not null,
    version bigint not null default 0
);

create index idx_availability_slot_provider_id on availability_slot (provider_id);
