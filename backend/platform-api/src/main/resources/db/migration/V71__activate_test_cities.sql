-- Activate test cities for local development and deployment
-- This enables Almaty and Shymkent for testing the city selection feature

update city set active = true where code in ('almaty', 'shymkent');
