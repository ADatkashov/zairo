-- The mechanic may be an existing registered user picked by the business owner (name and photo come from the
-- profile); null for entries typed in by hand before that existed.
alter table auto_mechanic add column user_id uuid references app_user (id);
create unique index uq_auto_mechanic_provider_user on auto_mechanic (provider_id, user_id) where user_id is not null;
