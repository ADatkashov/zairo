-- Smart Fill Engine: fills a slot freed by a cancelled booking by finding,
-- scoring, and staging offers to the most relevant customers. See
-- smartfill's own package-info.java for the module's design.
--
-- Cross-module ids (provider_id, service_id, employee_id, availability_slot_id,
-- cancelled_booking_id, recovered_booking_id, user_id on the offer table)
-- are bare uuid columns with no FK, matching this codebase's established
-- convention (see docs/erd/core-domain.md) -- the one exception is
-- candidate_offer.user_id, which references app_user directly the same way
-- in_app_notification.recipient_user_id does (V44): a genuine ownership
-- link smart-fill needs for its own authorization checks, not just an
-- association.
create table smart_fill_campaign (
    id uuid primary key,
    provider_id uuid not null,
    service_id uuid not null,
    employee_id uuid,
    availability_slot_id uuid not null,
    -- Duplicate-campaign protection: BookingCancelledEvent is published at
    -- most once per cancellation, but this makes "one campaign per
    -- cancelled booking" a real database guarantee, not just an assumption
    -- about event delivery.
    cancelled_booking_id uuid not null,
    slot_starts_at timestamptz not null,
    slot_ends_at timestamptz not null,
    status varchar(20) not null,
    current_stage int not null default 0,
    -- Null once the campaign has left NOTIFYING (BOOKED/EXPIRED/CANCELLED)
    -- or before its first stage has gone out.
    next_stage_at timestamptz,
    recovered_booking_id uuid,
    price_amount numeric(10, 2) not null,
    price_currency varchar(3) not null,
    created_at timestamptz not null,
    completed_at timestamptz,
    version bigint not null default 0
);

create unique index idx_smart_fill_campaign_cancelled_booking_id on smart_fill_campaign (cancelled_booking_id);
create index idx_smart_fill_campaign_provider_id on smart_fill_campaign (provider_id);
create index idx_smart_fill_campaign_availability_slot_id on smart_fill_campaign (availability_slot_id);
-- SmartFillCampaignJob's sweep target: every campaign due for its next
-- stage (or expiry check), grouped by status first since that's the
-- selective predicate.
create index idx_smart_fill_campaign_status_next_stage_at on smart_fill_campaign (status, next_stage_at);

create table smart_fill_candidate_offer (
    id uuid primary key,
    campaign_id uuid not null references smart_fill_campaign (id),
    -- Denormalized from smart_fill_campaign.provider_id -- per-business
    -- cooldown/limit checks (NotificationPolicy) need "has this user been
    -- offered anything from this provider recently" for every candidate of
    -- every new campaign, without a join back to the campaign table.
    provider_id uuid not null,
    user_id uuid not null references app_user (id),
    score int not null,
    rank int not null,
    stage int not null,
    matched_factors varchar(500) not null default '',
    status varchar(20) not null,
    notified_at timestamptz,
    responded_at timestamptz,
    booking_id uuid,
    created_at timestamptz not null,
    version bigint not null default 0,
    unique (campaign_id, user_id)
);

create index idx_smart_fill_candidate_offer_campaign_id on smart_fill_candidate_offer (campaign_id);
-- Per-user anti-spam checks (cooldown, decline cooldown, per-business limit)
-- always filter by user first, then status.
create index idx_smart_fill_candidate_offer_user_id_status on smart_fill_candidate_offer (user_id, status);
-- Daily/weekly notification-frequency limits scan by when a user was last
-- actually notified.
create index idx_smart_fill_candidate_offer_user_id_notified_at on smart_fill_candidate_offer (user_id, notified_at);
-- Per-business cooldown/limit: "has this user been notified by this
-- provider recently".
create index idx_smart_fill_candidate_offer_user_id_provider_id on smart_fill_candidate_offer (user_id, provider_id, notified_at);

-- One row per user who has ever opted out of Smart Fill suggestions --
-- absence of a row means "opted in" (the default), same "small table keyed
-- by userId, not a column bolted onto app_user" convention as favorite/
-- subscription.
create table smart_fill_user_preference (
    user_id uuid primary key references app_user (id),
    opted_out boolean not null default false,
    updated_at timestamptz not null
);
