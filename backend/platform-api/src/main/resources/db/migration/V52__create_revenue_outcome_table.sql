-- ZAIRO Decision Engine's outcome ledger -- one row per decision the engine
-- has ever made, resolved once the real outcome is known. See
-- revenueengine's own package-info.java for the full design.
create table revenue_outcome (
    id uuid primary key,
    action_type varchar(30) not null,
    provider_id uuid not null,
    -- Meaning depends on action_type's trigger (for SMART_FILL, the
    -- cancelled booking's id) -- bare uuid, no FK, same cross-module
    -- reference convention as every other id column in this schema (see
    -- docs/erd/core-domain.md).
    trigger_ref_id uuid not null,
    expected_value numeric(10, 2) not null,
    actual_revenue numeric(10, 2),
    currency varchar(3),
    -- Null = pending (decided but not yet resolved).
    recovered boolean,
    decided_at timestamptz not null,
    resolved_at timestamptz
);

-- One decision per (action_type, trigger) -- RevenueAttributionService.resolve's lookup key.
create unique index idx_revenue_outcome_action_type_trigger_ref_id on revenue_outcome (action_type, trigger_ref_id);
-- provider-insights' "Revenue Recovered by ZAIRO" panel scans by provider first.
create index idx_revenue_outcome_provider_id on revenue_outcome (provider_id);
