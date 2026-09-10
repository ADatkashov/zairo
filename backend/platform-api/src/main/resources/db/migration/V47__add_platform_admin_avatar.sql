-- Profile avatar for a platform staff account — nullable, same "no photo
-- yet" story as app_user.avatar_url (see V46's comment).
ALTER TABLE platform_admin_account ADD COLUMN avatar_url VARCHAR(2048);
