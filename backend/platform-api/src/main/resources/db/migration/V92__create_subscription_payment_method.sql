-- The card (recurring profile) a subscription is renewed with. Display data
-- only: the last four digits and the brand -- never a full card number.
create table subscription_payment_method (
    subscription_id      uuid primary key references subscription (id),
    provider             varchar(20)  not null,
    recurring_profile_id varchar(255) not null,
    card_last4           varchar(4),
    card_brand           varchar(20),
    created_at           timestamptz  not null,
    updated_at           timestamptz  not null
);

-- UPGRADE = the first PRO payment (customer present), RENEWAL = a later period.
alter table subscription_charge add column purpose varchar(20) not null default 'UPGRADE';

-- Backfill: every subscription that already has a recurring profile keeps it.
insert into subscription_payment_method (subscription_id, provider, recurring_profile_id, created_at, updated_at)
select distinct on (subscription_id) subscription_id, provider, recurring_profile_id, created_at, created_at
from subscription_charge
where recurring_profile_id is not null
order by subscription_id, created_at desc;
