create table in_app_notification (
    id uuid primary key,
    recipient_user_id uuid not null references app_user (id),
    type varchar(64) not null,
    title varchar(200) not null,
    body varchar(1000) not null,
    read boolean not null default false,
    created_at timestamptz not null
);

create index idx_in_app_notification_recipient on in_app_notification (recipient_user_id, created_at desc);
