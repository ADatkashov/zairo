-- The original unique index (V5) meant an availability_slot could ever be
-- the target of at most one booking, period -- but BookingService.cancelBooking
-- releases a cancelled booking's slot back to OPEN specifically so someone
-- else can book it again (see AvailabilitySlot.markOpen's own doc comment
-- and BookingApiTests.customerCancelsTheirOwnConfirmedBookingAndTheSlotReopens,
-- whose own comment -- "someone else can book it again" -- was never actually
-- exercised). A second booking against the same reopened slot would violate
-- this unique index and fail with a raw DB constraint error instead of the
-- clean 201 the reopened-slot flow is supposed to produce -- exactly the
-- flow Smart Fill depends on to refill a freed slot. Concurrent double-booking
-- protection was never this index's job anyway -- that's
-- availability_slot.version (optimistic locking, see AvailabilitySlot) plus
-- the OPEN -> BOOKED status transition; this index only ever needs to speed
-- up the existing booking -> availability_slot join (BookingRepository's
-- native queries), which a plain (non-unique) index does just as well.
drop index idx_booking_availability_slot_id;
create index idx_booking_availability_slot_id on booking (availability_slot_id);
