create table favorite (
    id uuid primary key,
    user_id uuid not null references app_user (id),
    provider_id uuid not null references provider (id),
    created_at timestamptz not null,
    unique (user_id, provider_id)
);

create index idx_favorite_user_id on favorite (user_id);
