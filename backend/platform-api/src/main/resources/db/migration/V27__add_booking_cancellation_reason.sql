-- Nullable — set only when a customer cancels and chooses to say why;
-- the endpoint accepts cancellation without one (see BookingDtos'
-- CancelBookingRequest doc comment for why it isn't required at the API
-- layer yet). NO_SHOW is a new BookingStatus enum value, not a schema
-- change — status is already stored as a plain varchar via
-- @Enumerated(EnumType.STRING).
alter table booking add column cancellation_reason text;
