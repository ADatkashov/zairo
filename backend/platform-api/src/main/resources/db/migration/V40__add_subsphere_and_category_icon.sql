-- Fourth catalog level: Category -> BusinessType (Сфера) -> Subsphere
-- (Подсфера) -> CatalogService. Mirrors business_type's shape exactly.
create table subsphere (
    id uuid primary key,
    business_type_id uuid not null references business_type (id),
    code varchar(50) not null unique,
    name_kk varchar(255) not null,
    name_ru varchar(255) not null,
    name_en varchar(255) not null,
    sort_order int not null default 0,
    status varchar(20) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index idx_subsphere_business_type_id on subsphere (business_type_id);

-- A catalog service can attach directly under a business type (as every
-- existing row does) or, once one exists, under a more specific subsphere
-- — nullable so the existing rows and every business type without
-- subspheres yet need no backfill.
alter table catalog_service add column subsphere_id uuid references subsphere (id);

create index idx_catalog_service_subsphere_id on catalog_service (subsphere_id);

-- Emoji shown next to a category in the discovery UI (e.g. the category
-- grid) — nullable so existing categories without one still work; backfilled
-- for beauty/auto below, and set on every new category in the next migration.
alter table category add column icon varchar(16);

update category set icon = '💇' where code = 'beauty';
update category set icon = '🚗' where code = 'auto';
