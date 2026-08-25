create table auto_mechanic (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    display_name varchar(255) not null,
    bio text,
    photo_url varchar(500),
    is_active boolean not null default true,
    created_at timestamptz not null
);

create index idx_auto_mechanic_provider_id on auto_mechanic (provider_id);
