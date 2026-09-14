-- Loyalty & Rewards: a business-scoped points ledger and reward catalog.
-- See loyalty's own package-info.java for the full design (business-scoped
-- accounts, immutable ledger + FIFO earn-lot expiry bookkeeping,
-- concurrency-safe redemption). Cross-module ids (provider_id, user_id,
-- service_id, booking_id, actor_user_id) are bare uuid columns with no FK,
-- same established convention as customer_profile (V55) and every other
-- cross-module reference in this codebase (see docs/erd/core-domain.md).

create table loyalty_program (
    id uuid primary key,
    provider_id uuid not null,
    enabled boolean not null default false,
    name varchar(200) not null,
    description text,
    fixed_points_per_booking int not null default 0,
    points_per_currency_unit numeric(10, 4) not null default 0,
    first_booking_bonus_points int not null default 0,
    repeat_visit_bonus_points int not null default 0,
    repeat_visit_threshold int not null default 2,
    review_bonus_points int not null default 0,
    points_per_currency_unit_redemption numeric(10, 4),
    min_redemption_points int,
    max_redemption_points_per_booking int,
    points_expire_enabled boolean not null default false,
    points_expiration_months int,
    daily_earning_points_cap int,
    monthly_earning_points_cap int,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    version bigint not null default 0
);

create unique index idx_loyalty_program_provider_id on loyalty_program (provider_id);

create table loyalty_milestone_rule (
    id uuid primary key,
    program_id uuid not null,
    visits_required int not null,
    points_awarded int not null,
    label varchar(200)
);

create index idx_loyalty_milestone_rule_program_id on loyalty_milestone_rule (program_id);

create table loyalty_tier_rule (
    id uuid primary key,
    program_id uuid not null,
    name varchar(100) not null,
    min_lifetime_points int not null
);

create index idx_loyalty_tier_rule_program_id on loyalty_tier_rule (program_id);

-- One customer's balance with one business -- see LoyaltyAccount's own doc
-- comment. points_balance is a cache kept in lock-step with
-- loyalty_transaction inserts inside the same DB transaction; the ledger
-- remains the actual source of truth.
create table loyalty_account (
    id uuid primary key,
    provider_id uuid not null,
    user_id uuid not null,
    points_balance int not null default 0,
    lifetime_earned int not null default 0,
    lifetime_redeemed int not null default 0,
    lifetime_expired int not null default 0,
    completed_visits int not null default 0,
    last_activity_at timestamptz,
    created_at timestamptz not null,
    version bigint not null default 0,
    constraint chk_loyalty_account_balance_non_negative check (points_balance >= 0)
);

create unique index idx_loyalty_account_provider_user on loyalty_account (provider_id, user_id);
-- LoyaltyDashboardService's "active members" / overview aggregates.
create index idx_loyalty_account_provider_last_activity on loyalty_account (provider_id, last_activity_at);

-- FIFO expiry bookkeeping -- one row per points-adding transaction, mutable
-- points_remaining decremented by redemption/expiration. See
-- LoyaltyEarnLot's own doc comment.
create table loyalty_earn_lot (
    id uuid primary key,
    provider_id uuid not null,
    user_id uuid not null,
    transaction_id uuid not null,
    points_earned int not null,
    points_remaining int not null,
    earned_at timestamptz not null,
    expires_at timestamptz,
    version bigint not null default 0,
    constraint chk_loyalty_earn_lot_remaining_non_negative check (points_remaining >= 0),
    constraint chk_loyalty_earn_lot_remaining_le_earned check (points_remaining <= points_earned)
);

create unique index idx_loyalty_earn_lot_transaction_id on loyalty_earn_lot (transaction_id);
-- LoyaltyLedgerService#consume's FIFO scan (oldest lot with remaining>0 first).
create index idx_loyalty_earn_lot_account_earned_at on loyalty_earn_lot (provider_id, user_id, earned_at)
    where points_remaining > 0;
-- LoyaltyExpirationJob's daily sweep target -- indexed so it finds due lots
-- without scanning every account's full history (Phase 23).
create index idx_loyalty_earn_lot_expires_at on loyalty_earn_lot (expires_at) where points_remaining > 0;

-- The immutable ledger -- every balance change, ever, one row each. Never
-- updated after insert; see LoyaltyTransaction's own doc comment.
create table loyalty_transaction (
    id uuid primary key,
    provider_id uuid not null,
    user_id uuid not null,
    type varchar(20) not null,
    points_delta int not null,
    balance_after int not null,
    reason varchar(500) not null,
    reference_type varchar(30),
    reference_id uuid,
    booking_id uuid,
    reward_id uuid,
    redemption_id uuid,
    actor_user_id uuid,
    created_at timestamptz not null,
    expires_at timestamptz
);

-- LoyaltyController's customer-facing history, newest first.
create index idx_loyalty_transaction_account_created_at on loyalty_transaction (provider_id, user_id, created_at desc);
-- LoyaltyLedgerService's daily/monthly earning-cap window sum.
create index idx_loyalty_transaction_account_type_created_at on loyalty_transaction (provider_id, user_id, type, created_at);
create index idx_loyalty_transaction_redemption_id on loyalty_transaction (redemption_id) where redemption_id is not null;

-- Duplicate-award protection (Phase 19) -- the actual enforcement point,
-- not just an application-level check. One BOOKING_EARNING/REVIEW_BONUS/
-- REPEAT_VISIT_BONUS per booking; at most one FIRST_BOOKING_BONUS per
-- account, ever; at most one award per (account, milestone).
create unique index uq_loyalty_transaction_booking_reference on loyalty_transaction (provider_id, user_id,
    reference_type, reference_id)
    where reference_type in ('BOOKING_EARNING', 'REVIEW_BONUS', 'REPEAT_VISIT_BONUS');
create unique index uq_loyalty_transaction_first_booking_bonus on loyalty_transaction (provider_id, user_id)
    where reference_type = 'FIRST_BOOKING_BONUS';
create unique index uq_loyalty_transaction_milestone on loyalty_transaction (provider_id, user_id, reference_id)
    where reference_type = 'MILESTONE';

-- A business's own reward catalog. discount_amount/discount_currency/
-- discount_percentage/service_id are only meaningful for the reward's own
-- type (see LoyaltyReward#isRedeemableAt and LoyaltyRewardService's own
-- per-type validation) -- no NOT NULL/CHECK enforcing "exactly one of
-- these" at the DB level, same permissiveness this codebase already
-- extends to e.g. cancellation_reason on booking.
create table loyalty_reward (
    id uuid primary key,
    provider_id uuid not null,
    name varchar(200) not null,
    description text,
    type varchar(30) not null,
    points_cost int not null,
    discount_amount numeric(12, 2),
    discount_currency varchar(3),
    discount_percentage numeric(5, 2),
    service_id uuid,
    max_redemptions int,
    redemptions_count int not null default 0,
    starts_at timestamptz,
    ends_at timestamptz,
    active boolean not null default true,
    terms text,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    version bigint not null default 0,
    constraint chk_loyalty_reward_points_cost_positive check (points_cost > 0)
);

-- The customer-facing "redeemable now" read (LoyaltyRewardRepository#findRedeemableNow).
create index idx_loyalty_reward_provider_active on loyalty_reward (provider_id, active);

-- One customer's redemption of one reward -- the reward's shape is
-- snapshotted onto this row at redemption time (see LoyaltyRedemption's
-- own doc comment), so editing the catalog later never rewrites history.
create table loyalty_redemption (
    id uuid primary key,
    provider_id uuid not null,
    user_id uuid not null,
    reward_id uuid not null,
    points_spent int not null,
    code varchar(12) not null,
    status varchar(20) not null,
    reward_name_snapshot varchar(200) not null,
    reward_type_snapshot varchar(30) not null,
    discount_amount_snapshot numeric(12, 2),
    discount_currency_snapshot varchar(3),
    discount_percentage_snapshot numeric(5, 2),
    created_at timestamptz not null,
    expires_at timestamptz,
    applied_booking_id uuid,
    applied_at timestamptz,
    cancelled_at timestamptz,
    cancel_reason varchar(500),
    version bigint not null default 0,
    constraint chk_loyalty_redemption_points_spent_positive check (points_spent > 0)
);

create unique index idx_loyalty_redemption_code on loyalty_redemption (code);
create index idx_loyalty_redemption_user_created_at on loyalty_redemption (user_id, created_at desc);
create index idx_loyalty_redemption_provider_created_at on loyalty_redemption (provider_id, created_at desc);
-- LoyaltyRedemptionService#applyToBooking's per-booking points-cap check.
create index idx_loyalty_redemption_applied_booking on loyalty_redemption (applied_booking_id, status)
    where applied_booking_id is not null;
-- LoyaltyExpirationJob's daily sweep for unused, past-validity redemption codes.
create index idx_loyalty_redemption_status_expires_at on loyalty_redemption (status, expires_at)
    where status = 'ACTIVE';
