create table staff_invitation (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    phone varchar(32) not null,
    kind varchar(16) not null,
    status varchar(16) not null,
    failure_reason varchar(255),
    accepted_user_id uuid references app_user (id),
    created_at timestamp with time zone not null,
    resolved_at timestamp with time zone
);

create index idx_staff_invitation_provider_id on staff_invitation (provider_id);
create index idx_staff_invitation_phone_status on staff_invitation (phone, status);
-- One open invitation per business and number.
create unique index uq_staff_invitation_pending on staff_invitation (provider_id, phone) where status = 'PENDING';
