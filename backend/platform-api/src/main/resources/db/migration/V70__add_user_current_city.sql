-- Add current_city_code to app_user to track user's selected/current city
-- Allows users to change their city and book services in different cities

alter table app_user add column current_city_code varchar(255);

-- Create foreign key constraint to cities table
alter table app_user add constraint fk_app_user_city
    foreign key (current_city_code) references city (code);

-- Index for efficient queries
create index idx_app_user_current_city_code on app_user (current_city_code);
