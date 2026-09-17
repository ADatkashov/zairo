-- Nullable: most messages are general conversation, not tied to one
-- booking. Set when a customer starts a message from a specific booking's
-- detail screen ("Message business about this booking") — lets the thread
-- show a booking chip/quick-open action on that message. No FK to booking
-- (cross-module reference by id only, same convention as
-- availability_slot.employee_id).
alter table message add column booking_id uuid;
