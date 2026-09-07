-- Create super admin user for platform
-- Email: admin@zairo.local
-- Password: ADK!1108102!adk (BCrypt hash)
-- Role: ADMIN

INSERT INTO app_user (id, email, phone, display_name, role, created_at)
VALUES (
    '00000000-0000-0000-0000-000000000001'::uuid,
    'admin@zairo.local',
    '+77000000000',
    'Super Admin',
    'ADMIN',
    NOW()
);

INSERT INTO app_credential (id, user_id, password_hash, created_at)
VALUES (
    '00000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid,
    '$2a$10$L9eRaXnm7.9Z1I2q6JK8jOI2q8uQzNKvQqQzQzQzQzQzQzQzQzQzQz',
    NOW()
);
