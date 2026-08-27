create table category (
    id uuid primary key,
    code varchar(50) not null unique,
    name_kk varchar(255) not null,
    name_ru varchar(255) not null,
    name_en varchar(255) not null,
    sort_order int not null default 0,
    status varchar(20) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create table business_type (
    id uuid primary key,
    category_id uuid not null references category (id),
    code varchar(50) not null unique,
    name_kk varchar(255) not null,
    name_ru varchar(255) not null,
    name_en varchar(255) not null,
    sort_order int not null default 0,
    status varchar(20) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index idx_business_type_category_id on business_type (category_id);

create table catalog_service (
    id uuid primary key,
    business_type_id uuid not null references business_type (id),
    name_kk varchar(255) not null,
    name_ru varchar(255) not null,
    name_en varchar(255) not null,
    sort_order int not null default 0,
    status varchar(20) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index idx_catalog_service_business_type_id on catalog_service (business_type_id);

alter table provider add column business_type_id uuid references business_type (id);
alter table service add column catalog_service_id uuid references catalog_service (id);

-- Minimal seed — exactly enough to cover today's real data (provider.vertical
-- is either 'beauty' or 'auto'), not the full 20-category catalog from the
-- original product brief. Fixed literal ids, not gen_random_uuid(), so the
-- backfill below can reference them deterministically within this same file.
insert into category (id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at) values
    ('a1111111-1111-4111-8111-111111111111', 'beauty', 'Сұлулық', 'Красота', 'Beauty', 1, 'ACTIVE', now(), now()),
    ('a2222222-2222-4222-8222-222222222222', 'auto', 'Авто', 'Авто', 'Auto', 2, 'ACTIVE', now(), now());

insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at) values
    ('b1111111-1111-4111-8111-111111111111', 'a1111111-1111-4111-8111-111111111111', 'beauty_salon',
        'Сұлулық салоны', 'Салон красоты', 'Beauty Salon', 1, 'ACTIVE', now(), now()),
    ('b2222222-2222-4222-8222-222222222222', 'a2222222-2222-4222-8222-222222222222', 'auto_service',
        'Автосервис', 'Автосервис', 'Auto Service', 1, 'ACTIVE', now(), now());

update provider set business_type_id = 'b1111111-1111-4111-8111-111111111111' where vertical = 'beauty';
update provider set business_type_id = 'b2222222-2222-4222-8222-222222222222' where vertical = 'auto';

-- service.catalog_service_id is deliberately left null on every existing row
-- — free-text titles are too varied to auto-match to a catalog entry safely
-- (see the ADR). Businesses link their own offerings to the catalog later.
