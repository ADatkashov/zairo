-- Nullable, no FK — Core stores this as an opaque id (a vertical-beauty
-- Master id, a vertical-auto Mechanic id, ...) without knowing which
-- vertical table it points into. Null on every existing row and every row
-- a provider doesn't opt into per-employee scheduling for — unchanged
-- "shared across the whole provider" behavior.
alter table availability_slot add column employee_id uuid;

create index idx_availability_slot_employee_id on availability_slot (employee_id);
