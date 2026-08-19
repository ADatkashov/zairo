create table credential (
    id uuid primary key,
    user_id uuid not null unique references app_user (id),
    password_hash varchar(255) not null,
    created_at timestamptz not null
);

create table refresh_token (
    id uuid primary key,
    user_id uuid not null references app_user (id),
    token_hash varchar(255) not null unique,
    expires_at timestamptz not null,
    created_at timestamptz not null
);

create index idx_refresh_token_user_id on refresh_token (user_id);
