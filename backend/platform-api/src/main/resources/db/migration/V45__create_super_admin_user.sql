-- Create super admin user for platform
-- Email: admin@zairo.local
-- Password: ADK!1108102!adk (BCrypt hash)
-- Role: ADMIN

INSERT INTO app_user (id, email, phone, display_name, role, created_at)
VALUES (
    '00000000-0000-0000-0000-000000000099'::uuid,
    'admin@zairo.local',
    '+77000000000',
    'Super Admin',
    'ADMIN',
    NOW()
);

INSERT INTO app_credential (id, user_id, password_hash, created_at)
VALUES (
    '00000000-0000-0000-0000-000000000100'::uuid,
    '00000000-0000-0000-0000-000000000099'::uuid,
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P6.5ma',
    NOW()
);
