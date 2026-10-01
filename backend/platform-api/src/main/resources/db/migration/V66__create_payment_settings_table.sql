create table payment_settings (
    id uuid primary key,
    provider_id uuid not null unique references provider (id),
    deposit_type varchar(20) not null default 'NO_PAYMENT',
    deposit_value_type varchar(20),
    deposit_value numeric(10, 2),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    version bigint not null default 0
);

create index idx_payment_settings_provider_id on payment_settings (provider_id);
