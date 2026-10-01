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

-- Insert all major cities for Kazakhstan (initially inactive, enable through Platform Admin as needed)
insert into city (code, name, name_kk, country_code, timezone, currency, latitude, longitude, default_search_radius_km, active)
values
    -- Active by default (tier 1 cities)
    ('almaty', 'Almaty', 'Алматы', 'KZ', 'Asia/Almaty', 'KZT', 43.238056, 77.064444, 50, true),
    ('shymkent', 'Shymkent', 'Шымкент', 'KZ', 'Asia/Almaty', 'KZT', 42.309167, 69.596667, 50, true),

    -- Major cities (inactive, to be enabled later)
    ('almaty-region', 'Almaty Region', 'Түркістан облысы', 'KZ', 'Asia/Almaty', 'KZT', 45.000000, 77.500000, 50, false),
    ('aktau', 'Aktau', 'Ақтау', 'KZ', 'Asia/Almaty', 'KZT', 43.657700, 51.169400, 50, false),
    ('aktobe', 'Aktobe', 'Ақтөбе', 'KZ', 'Asia/Almaty', 'KZT', 50.283333, 57.166667, 50, false),
    ('atyrau', 'Atyrau', 'Атырау', 'KZ', 'Asia/Almaty', 'KZT', 43.700000, 51.300000, 50, false),
    ('karaganda', 'Karaganda', 'Қарағанды', 'KZ', 'Asia/Almaty', 'KZT', 49.800000, 73.100000, 50, false),
    ('kokshetau', 'Kokshetau', 'Қоқшетау', 'KZ', 'Asia/Almaty', 'KZT', 52.283333, 75.450000, 50, false),
    ('kostanay', 'Kostanay', 'Қостанай', 'KZ', 'Asia/Almaty', 'KZT', 53.200000, 63.630000, 50, false),
    ('lisakovsk', 'Lisakovsk', 'Лисаковск', 'KZ', 'Asia/Almaty', 'KZT', 52.966667, 62.433333, 50, false),
    ('oral', 'Oral', 'Орал', 'KZ', 'Asia/Almaty', 'KZT', 51.366667, 51.366667, 50, false),
    ('pavlodar', 'Pavlodar', 'Павлодар', 'KZ', 'Asia/Almaty', 'KZT', 52.283333, 76.933333, 50, false),
    ('petropavlovsk', 'Petropavlovsk', 'Петропавл', 'KZ', 'Asia/Almaty', 'KZT', 54.866667, 69.166667, 50, false),
    ('rudny', 'Rudny', 'Рудный', 'KZ', 'Asia/Almaty', 'KZT', 52.433333, 63.850000, 50, false),
    ('semey', 'Semey', 'Семей', 'KZ', 'Asia/Almaty', 'KZT', 50.416667, 80.250000, 50, false),
    ('taldykorgan', 'Taldykorgan', 'Талдықорған', 'KZ', 'Asia/Almaty', 'KZT', 45.766667, 78.366667, 50, false),
    ('taraz', 'Taraz', 'Тараз', 'KZ', 'Asia/Almaty', 'KZT', 42.900000, 71.366667, 50, false),
    ('temirtau', 'Temirtau', 'Теміртау', 'KZ', 'Asia/Almaty', 'KZT', 50.050000, 72.600000, 50, false),
    ('turkestan', 'Turkestan', 'Түркістан', 'KZ', 'Asia/Almaty', 'KZT', 43.266667, 68.283333, 50, false),
    ('uralsk', 'Uralsk', 'Орал', 'KZ', 'Asia/Almaty', 'KZT', 51.233333, 51.400000, 50, false),
    ('ust-kamenogorsk', 'Ust-Kamenogorsk', 'Өскемен', 'KZ', 'Asia/Almaty', 'KZT', 49.983333, 82.616667, 50, false);
