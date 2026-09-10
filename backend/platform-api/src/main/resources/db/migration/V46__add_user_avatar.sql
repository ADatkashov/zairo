-- Profile avatar for a user's own account — nullable, same "no photo yet"
-- story as staff/master/mechanic/cleaner photoUrl (see V43's comment).
ALTER TABLE app_user ADD COLUMN avatar_url VARCHAR(2048);
