-- favorite.provider_id already has an FK (references provider(id)) but
-- Postgres doesn't index the referencing side of a foreign key for free --
-- only favorite(user_id) had an index (V8). smart-fill's candidate finder
-- now queries "who favorited this provider" (FavoriteRepository.findByProviderId)
-- for every cancelled-booking campaign, so this needs to be fast too.
create index idx_favorite_provider_id on favorite (provider_id);
