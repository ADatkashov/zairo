create table cleaning_cleaner (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    display_name varchar(255) not null,
    bio text,
    photo_url varchar(500),
    is_active boolean not null default true,
    created_at timestamptz not null
);

create index idx_cleaning_cleaner_provider_id on cleaning_cleaner (provider_id);
