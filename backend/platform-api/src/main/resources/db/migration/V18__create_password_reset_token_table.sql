create table password_reset_token (
    id uuid primary key,
    user_id uuid not null references app_user (id),
    token_hash varchar(255) not null unique,
    expires_at timestamptz not null,
    created_at timestamptz not null
);

create index idx_password_reset_token_user_id on password_reset_token (user_id);
