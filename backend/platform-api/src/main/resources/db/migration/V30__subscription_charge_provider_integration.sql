-- ADR-0006 — see SubscriptionCharge.java's own field-by-field doc comments.

alter table subscription_charge add column provider varchar(20);
update subscription_charge set provider = 'MOCK' where provider is null;
alter table subscription_charge alter column provider set not null;

alter table subscription_charge add column recurring_profile_id varchar(255);

create index idx_subscription_charge_recurring_profile_id on subscription_charge (recurring_profile_id);
