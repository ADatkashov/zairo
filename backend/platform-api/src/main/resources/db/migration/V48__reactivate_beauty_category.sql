-- Same incident as V45, again: a platform admin working in the Categories
-- tab's ACTIVE/INACTIVE toggle took "beauty" out of the public catalog by
-- mistake. This time the row itself is most likely still there (the toggle
-- only flips status, GET /categories is ACTIVE-only) rather than actually
-- deleted, but this covers both: reactivate the row if it's
-- INACTIVE/ARCHIVED, and restore it from scratch (same fixed id V25/V45
-- used) if it was removed outright. Same idempotent shape as V45 — a no-op
-- once "beauty" is ACTIVE again.
update category set status = 'ACTIVE', updated_at = now()
where code = 'beauty' and status <> 'ACTIVE';

insert into category (id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select 'a1111111-1111-4111-8111-111111111111', 'beauty', 'Сұлулық', 'Красота', 'Beauty', 1, 'ACTIVE', now(), now()
where not exists (select 1 from category where code = 'beauty');

update business_type set status = 'ACTIVE', updated_at = now()
where code = 'beauty_salon' and status <> 'ACTIVE';

insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select 'b1111111-1111-4111-8111-111111111111', c.id, 'beauty_salon', 'Сұлулық салоны', 'Салон красоты',
    'Beauty Salon', 1, 'ACTIVE', now(), now()
from category c
where c.code = 'beauty'
  and not exists (select 1 from business_type where code = 'beauty_salon');
