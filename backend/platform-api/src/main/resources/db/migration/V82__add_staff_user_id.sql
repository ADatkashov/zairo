-- The staff may be an existing registered user picked by the business owner (name and photo come from the
-- profile); null for entries typed in by hand before that existed.
alter table staff add column user_id uuid references app_user (id);
create unique index uq_staff_provider_user on staff (provider_id, user_id) where user_id is not null;
