create table provider (
    id uuid primary key,
    owner_user_id uuid not null references app_user (id),
    name varchar(255) not null,
    vertical varchar(50) not null,
    status varchar(30) not null,
    created_at timestamptz not null
);

create index idx_provider_vertical on provider (vertical);
