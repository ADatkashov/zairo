package com.zairo.factory.booking;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

public final class AvailabilitySlotDtos {

    private AvailabilitySlotDtos() {
    }

    public record CreateAvailabilitySlotRequest(Instant startsAt, Instant endsAt) {
    }

    public record AvailabilitySlotResponse(UUID id, UUID providerId, Instant startsAt, Instant endsAt,
            AvailabilityStatus status) {
        static AvailabilitySlotResponse from(AvailabilitySlot slot) {
            return new AvailabilitySlotResponse(slot.getId(), slot.getProviderId(), slot.getStartsAt(),
                    slot.getEndsAt(), slot.getStatus());
        }
    }

    /**
     * {@code zoneId} (an IANA zone id, e.g. "Asia/Almaty") is required
     * explicitly rather than assumed — {@code Provider} has no timezone
     * field of its own (nothing in this project has needed one before
     * recurring schedules), and guessing the server's zone would silently
     * generate slots at the wrong wall-clock time for an owner in a
     * different zone. {@code holidays} are dates to skip entirely, even if
     * they fall on a selected day of week. Slots that would overlap an
     * already-existing slot (any status) are skipped, not overwritten —
     * see RecurringScheduleService's doc comment for why.
     */
    public record RecurringScheduleRequest(List<DayOfWeek> daysOfWeek, LocalTime startTime, LocalTime endTime,
            int slotDurationMinutes, int breakMinutes, LocalDate rangeStart, LocalDate rangeEnd,
            List<LocalDate> holidays, String zoneId) {
    }

    public record RecurringScheduleResult(List<AvailabilitySlotResponse> created, int skippedConflictCount) {
    }
}
