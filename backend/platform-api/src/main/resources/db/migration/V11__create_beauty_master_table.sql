create table beauty_master (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    display_name varchar(255) not null,
    bio text,
    photo_url varchar(500),
    is_active boolean not null default true,
    created_at timestamptz not null
);

create index idx_beauty_master_provider_id on beauty_master (provider_id);
