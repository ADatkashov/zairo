-- A customer's saved cards (provider recurring profiles). Display data only:
-- last four digits and brand, never a full card number.
create table saved_card (
    id                   uuid primary key,
    user_id              uuid         not null,
    provider             varchar(20)  not null,
    recurring_profile_id varchar(255) not null,
    card_last4           varchar(4),
    card_brand           varchar(20),
    created_at           timestamptz  not null,
    constraint uq_saved_card_user_profile unique (user_id, recurring_profile_id)
);
create index idx_saved_card_user on saved_card (user_id);

-- "Save my card when I pay": a provider can only create a reusable profile
-- during a real payment, so saving is a per-user switch that the next online
-- payment honours.
create table saved_card_preference (
    user_id               uuid primary key,
    save_on_next_payment  boolean     not null,
    updated_at            timestamptz not null
);

-- This payment was started so that the card used is kept afterwards.
alter table payment add column save_card boolean not null default false;
