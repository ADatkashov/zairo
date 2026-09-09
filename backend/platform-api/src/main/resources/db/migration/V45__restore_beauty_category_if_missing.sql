-- Defensive re-seed, not a new feature: the Control Center had no
-- moderator/business-moderation surface and no confirmation step before a
-- taxonomy status toggle, so an admin who needed to fix something reached
-- straight for the database instead — and a raw DELETE against `category`
-- (rather than the app's ACTIVE/INACTIVE toggle) took the "beauty" row out
-- entirely. Idempotent by design (NOT EXISTS guards on the same fixed ids
-- V25__create_catalog_tables.sql used) — a no-op everywhere "beauty" is
-- still present, a restore everywhere it isn't. Doesn't touch
-- business_type/subsphere/catalog_service rows underneath it: those are
-- untouched by a category-only delete and this migration doesn't guess at
-- data it can't verify was actually lost.
insert into category (id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select 'a1111111-1111-4111-8111-111111111111', 'beauty', 'Сұлулық', 'Красота', 'Beauty', 1, 'ACTIVE', now(), now()
where not exists (select 1 from category where code = 'beauty');

insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select 'b1111111-1111-4111-8111-111111111111', c.id, 'beauty_salon', 'Сұлулық салоны', 'Салон красоты',
    'Beauty Salon', 1, 'ACTIVE', now(), now()
from category c
where c.code = 'beauty'
  and not exists (select 1 from business_type where code = 'beauty_salon');
