-- V60 declared allowed_hours_start/end as smallint and
-- reactivation_interval_multiplier as numeric(6, 2), but the
-- AutomationSettings entity maps them as Integer/Double, so Hibernate's
-- schema validator (ddl-auto=validate) rejects the mismatch on startup.
-- Align the columns with the entity's actual mapped types instead of the
-- entity, since every other Integer-mapped column in this table is a plain
-- "int" and the multiplier is read/written as Double everywhere in the
-- automation module (AutomationDtos, AutomationSettingsService).

alter table automation_settings alter column allowed_hours_start type integer;
alter table automation_settings alter column allowed_hours_end type integer;
alter table automation_settings alter column reactivation_interval_multiplier type double precision;
