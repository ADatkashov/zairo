create table subscription (
    id uuid primary key,
    owner_user_id uuid not null unique,
    plan varchar(20) not null,
    status varchar(20) not null,
    current_period_start timestamptz not null,
    current_period_end timestamptz not null,
    grace_period_ends_at timestamptz,
    cancel_at_period_end boolean not null default false,
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index idx_subscription_owner_user_id on subscription (owner_user_id);
create index idx_subscription_current_period_end on subscription (current_period_end);
create index idx_subscription_grace_period_ends_at on subscription (grace_period_ends_at);

create table subscription_charge (
    id uuid primary key,
    subscription_id uuid not null references subscription (id),
    amount numeric not null,
    currency varchar(3) not null,
    status varchar(20) not null,
    provider_reference varchar(255),
    failure_reason varchar(500),
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index idx_subscription_charge_subscription_id on subscription_charge (subscription_id);
