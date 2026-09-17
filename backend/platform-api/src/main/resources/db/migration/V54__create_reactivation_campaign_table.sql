-- Lost Customer Recovery: a daily sweep for customers who have gone quiet
-- well past their usual visit interval (or a flat long-inactivity floor,
-- absent an established pattern), and a win-back nudge for each one found.
-- See reactivationengine's own package-info.java for the module's design.
--
-- Cross-module ids (provider_id, service_id, user_id, last_visit_booking_id,
-- recovered_booking_id) are bare uuid columns with no FK, matching this
-- codebase's established convention (see docs/erd/core-domain.md), same as
-- rebook_campaign (V53).
create table reactivation_campaign (
    id uuid primary key,
    provider_id uuid not null,
    service_id uuid not null,
    user_id uuid not null,
    last_visit_booking_id uuid not null,
    last_visit_at timestamptz not null,
    inactivity_days_at_creation int not null,
    expires_at timestamptz not null,
    status varchar(20) not null,
    recovered_booking_id uuid,
    price_amount numeric(10, 2) not null,
    price_currency varchar(3) not null,
    created_at timestamptz not null,
    completed_at timestamptz,
    version bigint not null default 0
);

create unique index idx_reactivation_campaign_last_visit_booking_id on reactivation_campaign (last_visit_booking_id);
create index idx_reactivation_campaign_status_expires_at on reactivation_campaign (status, expires_at);
create index idx_reactivation_campaign_user_id_provider_id_status on reactivation_campaign (user_id, provider_id, status);
