-- Third vertical (V25 seeded beauty/auto) — same minimal-seed reasoning:
-- exactly enough to cover the new vertical-cleaning module, not the full
-- 20-category catalog from the original product brief. Fixed literal ids,
-- not gen_random_uuid(), to match V25's own convention.
insert into category (id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at) values
    ('a3333333-3333-4333-8333-333333333333', 'cleaning', 'Тазалау', 'Уборка', 'Cleaning', 3, 'ACTIVE', now(), now());

insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at) values
    ('b3333333-3333-4333-8333-333333333333', 'a3333333-3333-4333-8333-333333333333', 'cleaning_company',
        'Тазалау компаниясы', 'Клининговая компания', 'Cleaning Company', 1, 'ACTIVE', now(), now());
