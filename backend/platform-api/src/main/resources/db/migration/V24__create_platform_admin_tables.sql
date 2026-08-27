create table platform_admin_account (
    id uuid primary key,
    email varchar(255) not null unique,
    password_hash varchar(255) not null,
    display_name varchar(255) not null,
    role varchar(20) not null,
    active boolean not null default true,
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create table platform_audit_log (
    id uuid primary key,
    actor_id uuid not null references platform_admin_account (id),
    actor_email varchar(255) not null,
    action varchar(60) not null,
    target_type varchar(40),
    target_id uuid,
    previous_value text,
    new_value text,
    reason text,
    created_at timestamptz not null
);

create index idx_platform_audit_log_target on platform_audit_log (target_type, target_id);
create index idx_platform_audit_log_created_at on platform_audit_log (created_at);
