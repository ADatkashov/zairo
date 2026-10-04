-- Manual greetings a business owner sends to a loyalty member (e.g. from the
-- "Birthdays" list), optionally with a bonus of points. The table doubles as
-- the audit trail (who sent what, when) and as the "at most one greeting per
-- member per day" guard: the unique index makes a double-click or a retry
-- impossible to apply twice, enforced by the database.
create table loyalty_greeting (
    id uuid primary key,
    provider_id uuid not null,
    user_id uuid not null,
    sent_by_user_id uuid not null,
    message varchar(500),
    bonus_points integer not null default 0,
    greeting_date date not null,
    created_at timestamp with time zone not null,
    constraint chk_loyalty_greeting_bonus_non_negative check (bonus_points >= 0)
);

create unique index uq_loyalty_greeting_member_day on loyalty_greeting (provider_id, user_id, greeting_date);
create index idx_loyalty_greeting_provider_created_at on loyalty_greeting (provider_id, created_at desc);
