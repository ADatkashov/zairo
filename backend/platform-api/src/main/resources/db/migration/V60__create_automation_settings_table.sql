-- Automation Center: one settings row per provider, created lazily on
-- first access. Absence of a row means "run exactly as before" (every
-- engine enabled, every override null) -- an opt-out model, since Smart
-- Fill/Rebook/Reactivation already run for every provider today with no
-- settings screen at all. provider_id is a bare uuid column with no FK,
-- same established convention as every other cross-module reference in
-- this codebase (see docs/erd/core-domain.md).

create table automation_settings (
    id uuid primary key,
    provider_id uuid not null,
    rebook_enabled boolean not null default true,
    reactivation_enabled boolean not null default true,
    smart_fill_enabled boolean not null default true,
    rebook_min_visits_to_establish_interval int,
    rebook_min_interval_days int,
    rebook_max_interval_days int,
    rebook_follow_up_window_days int,
    reactivation_scan_min_inactivity_days int,
    reactivation_interval_multiplier numeric(6, 2),
    reactivation_absolute_max_inactivity_days int,
    reactivation_follow_up_window_days int,
    allowed_hours_start smallint,
    allowed_hours_end smallint,
    timezone varchar(64),
    cooldown_days_between_offers int,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    version bigint not null default 0
);

create unique index idx_automation_settings_provider_id on automation_settings (provider_id);
