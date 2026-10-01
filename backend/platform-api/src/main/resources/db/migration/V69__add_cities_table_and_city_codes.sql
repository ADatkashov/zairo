-- Create cities table for multi-city support
-- This table stores cities for each country, managed only through Platform Admin interface

create table city (
    id uuid primary key default gen_random_uuid(),
    code varchar(255) not null unique,
    name varchar(255) not null,
    name_kk varchar(255),
    country_code varchar(2) not null,
    timezone varchar(255) not null default 'Asia/Almaty',
    currency varchar(3) not null default 'KZT',
    latitude decimal(10, 8),
    longitude decimal(11, 8),
    default_search_radius_km integer default 50,
    active boolean not null default true,
    created_at timestamptz not null default current_timestamp,
    updated_at timestamptz not null default current_timestamp
);

create index idx_city_country_code on city (country_code);
create index idx_city_code on city (code);

-- Add city_code column to existing tables
alter table provider add column city_code varchar(255);
alter table booking add column city_code varchar(255);
alter table service add column city_code varchar(255);
alter table review add column city_code varchar(255);

-- Add foreign key constraints (cities can be null for backward compatibility initially)
alter table provider add constraint fk_provider_city foreign key (city_code) references city (code);
alter table booking add constraint fk_booking_city foreign key (city_code) references city (code);
alter table service add constraint fk_service_city foreign key (city_code) references city (code);
alter table review add constraint fk_review_city foreign key (city_code) references city (code);

-- Create indexes for city_code lookups
create index idx_provider_city_code on provider (city_code);
create index idx_booking_city_code on booking (city_code);
create index idx_service_city_code on service (city_code);
create index idx_review_city_code on review (city_code);

-- Insert initial cities for Kazakhstan
insert into city (code, name, name_kk, country_code, latitude, longitude, default_search_radius_km, active)
values
    ('almaty', 'Almaty', 'Алматы', 'KZ', 43.238056, 77.064444, 50, true),
    ('almaty-region', 'Almaty Region', 'Түркістан облысы', 'KZ', 45.000000, 77.500000, 50, true),
    ('shymkent', 'Shymkent', 'Шымкент', 'KZ', 42.309167, 69.596667, 50, true);
