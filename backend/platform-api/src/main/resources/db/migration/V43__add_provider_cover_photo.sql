-- Cover photo for a provider's card in discovery/search results — nullable,
-- same "no photo yet" story as staff/master/mechanic/cleaner photoUrl
-- columns (see V42). Owner sets it via PUT /providers/{id}, backed by the
-- existing generic storage module (backend/storage).
ALTER TABLE provider ADD COLUMN cover_photo_url VARCHAR(2048);
