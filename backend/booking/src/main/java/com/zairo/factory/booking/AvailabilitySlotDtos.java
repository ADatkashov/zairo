package com.zairo.factory.booking;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

public final class AvailabilitySlotDtos {

    private AvailabilitySlotDtos() {
    }

    // Both timestamps mirror availability_slot's not-null columns (V4
    // migration). Unlike RecurringScheduleRequest below, nothing checks
    // startsAt is actually before endsAt here today — not invented.
    public record CreateAvailabilitySlotRequest(
            @NotNull @Schema(example = "2026-09-01T10:00:00Z") Instant startsAt,
            @NotNull @Schema(example = "2026-09-01T10:30:00Z") Instant endsAt,
            @Schema(description = "Opaque vertical-employee id (a beauty Master or auto Mechanic id) if this "
                    + "slot belongs to one specific employee rather than the whole provider. Omit for today's "
                    + "shared-pool behavior.", example = "550e8400-e29b-41d4-a716-446655440000")
            UUID employeeId) {
        // Convenience constructor for callers that don't set an employee —
        // keeps every pre-existing 2-arg call site (mostly tests) compiling
        // without a mechanical find-and-replace, same precedent as
        // providers.ProviderDtos.CreateProviderRequest's own 3-arg overload.
        public CreateAvailabilitySlotRequest(Instant startsAt, Instant endsAt) {
            this(startsAt, endsAt, null);
        }
    }

    public record AvailabilitySlotResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "2026-09-01T10:00:00Z") Instant startsAt,
            @Schema(example = "2026-09-01T10:30:00Z") Instant endsAt,
            AvailabilityStatus status,
            @Schema(description = "Null if this slot is shared across the whole provider.",
                    example = "550e8400-e29b-41d4-a716-446655440000")
            UUID employeeId) {
        static AvailabilitySlotResponse from(AvailabilitySlot slot) {
            return new AvailabilitySlotResponse(slot.getId(), slot.getProviderId(), slot.getStartsAt(),
                    slot.getEndsAt(), slot.getStatus(), slot.getEmployeeId());
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
    public record RecurringScheduleRequest(
            @Schema(description = "At least one required.", example = "[\"MONDAY\", \"WEDNESDAY\"]")
            List<DayOfWeek> daysOfWeek,
            @Schema(example = "10:00:00") LocalTime startTime,
            @Schema(example = "18:00:00") LocalTime endTime,
            @Schema(description = "Must be positive.", example = "30") int slotDurationMinutes,
            @Schema(description = "Gap between consecutive generated slots. Cannot be negative.", example = "10")
            int breakMinutes,
            @Schema(example = "2026-09-01") LocalDate rangeStart,
            @Schema(description = "Range cannot exceed 92 days.", example = "2026-09-14") LocalDate rangeEnd,
            @Schema(description = "Dates to skip entirely, even on a selected day of week. May be empty.",
                    example = "[\"2026-09-07\"]") List<LocalDate> holidays,
            @Schema(description = "IANA zone id — Provider has no timezone field of its own, so this is "
                    + "required explicitly rather than assumed.", example = "Asia/Almaty") String zoneId,
            @Schema(description = "Opaque vertical-employee id — every generated slot belongs to this one "
                    + "employee rather than the shared provider pool. Omit for today's shared-pool behavior.",
                    example = "550e8400-e29b-41d4-a716-446655440000")
            UUID employeeId) {
        // Convenience constructor for pre-existing 8-arg call sites — same
        // precedent as CreateAvailabilitySlotRequest's own overload above.
        public RecurringScheduleRequest(List<DayOfWeek> daysOfWeek, LocalTime startTime, LocalTime endTime,
                int slotDurationMinutes, int breakMinutes, LocalDate rangeStart, LocalDate rangeEnd,
                List<LocalDate> holidays, String zoneId) {
            this(daysOfWeek, startTime, endTime, slotDurationMinutes, breakMinutes, rangeStart, rangeEnd, holidays,
                    zoneId, null);
        }
    }

    public record RecurringScheduleResult(
            List<AvailabilitySlotResponse> created,
            @Schema(description = "How many candidate slots were skipped because they overlapped a "
                    + "pre-existing slot — running the same request twice is safe, not additive.")
            int skippedConflictCount) {
    }
}
