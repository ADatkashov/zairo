-- A master may be an existing registered user picked by the business owner (name and photo come from the
-- profile); null for masters entered by hand before that existed.
alter table beauty_master add column user_id uuid references app_user (id);
create unique index uq_beauty_master_provider_user on beauty_master (provider_id, user_id) where user_id is not null;
