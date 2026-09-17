-- Rebook Engine: once a booking completes, watches whether this customer's
-- usual visit interval with the business has elapsed and, if so, nudges
-- them back. See rebookengine's own package-info.java for the module's
-- design.
--
-- Cross-module ids (provider_id, service_id, user_id, completed_booking_id,
-- recovered_booking_id) are bare uuid columns with no FK, matching this
-- codebase's established convention (see docs/erd/core-domain.md), same as
-- smart_fill_campaign (V51).
create table rebook_campaign (
    id uuid primary key,
    provider_id uuid not null,
    service_id uuid not null,
    user_id uuid not null,
    completed_booking_id uuid not null,
    last_visit_at timestamptz not null,
    average_interval_days int not null,
    due_at timestamptz not null,
    expires_at timestamptz not null,
    status varchar(20) not null,
    recovered_booking_id uuid,
    price_amount numeric(10, 2) not null,
    price_currency varchar(3) not null,
    created_at timestamptz not null,
    completed_at timestamptz,
    version bigint not null default 0
);

create unique index idx_rebook_campaign_completed_booking_id on rebook_campaign (completed_booking_id);
create index idx_rebook_campaign_status_due_at on rebook_campaign (status, due_at);
create index idx_rebook_campaign_status_expires_at on rebook_campaign (status, expires_at);
create index idx_rebook_campaign_user_id_provider_id_status on rebook_campaign (user_id, provider_id, status);
