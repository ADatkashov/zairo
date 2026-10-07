package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

/** The owner's schedule management: weekly hours, time off and per-business rules. */
public final class WorkerScheduleDtos {

    private WorkerScheduleDtos() {
    }

    @Schema(description = "One working interval on one weekday; a lunch break is two intervals.")
    public record HoursInterval(
            @Min(1) @Max(7) @Schema(description = "1 = Monday .. 7 = Sunday", example = "1") int dayOfWeek,
            @NotNull @Schema(example = "09:00:00") LocalTime startTime,
            @NotNull @Schema(example = "13:00:00") LocalTime endTime) {
    }

    public record SaveScheduleRequest(
            @NotBlank @Size(max = 64) @Schema(description = "IANA zone the hours are in.", example = "Asia/Almaty")
            String zoneId,
            @Min(5) @Max(480) @Schema(description = "Length of each bookable slot.", example = "60")
            int slotMinutes,
            @Min(0) @Max(240) @Schema(description = "Gap between consecutive slots.", example = "0")
            int breakMinutes,
            @NotNull @Size(min = 1, max = 28) List<@Valid HoursInterval> hours) {
    }

    @Schema(description = "A worker's weekly schedule. configured=false means the worker uses the business's "
            + "shared slots (no own schedule yet).")
    public record ScheduleResponse(UUID workerId, boolean configured, String zoneId, Integer slotMinutes,
            Integer breakMinutes, List<HoursInterval> hours) {
    }

    public record SaveScheduleResult(ScheduleResponse schedule, int slotsCreated, int slotsRemoved) {
    }

    public record WorkerSummaryResponse(
            UUID id, WorkerKind kind, String displayName, String photoUrl, boolean active,
            @Schema(description = "True when the worker has their own weekly schedule.") boolean scheduleConfigured,
            @Schema(description = "End of the time off that is in effect right now, if any.") Instant offUntil) {
    }

    public record TimeOffRequest(
            @NotNull Instant startsAt, @NotNull Instant endsAt,
            @Size(max = 255) @Schema(example = "Sick leave") String reason) {
    }

    public record TimeOffResponse(UUID id, UUID workerId, Instant startsAt, Instant endsAt, String reason,
            @Schema(description = "True when the worker themselves recorded it.") boolean byWorker) {
    }

    public record TimeOffCreatedResponse(
            TimeOffResponse timeOff,
            @Schema(description = "Appointments inside the period that still need the owner's decision. Nothing is "
                    + "cancelled: customers who said \"any master\" were handed to a free colleague, the rest "
                    + "(a named person, or nobody free) wait in the owner's list.") int affectedAppointments) {
    }

    public record WorkforceSettingsResponse(boolean allowWorkerChoice, boolean workerPricingEnabled) {
    }

    public record UpdateWorkforceSettingsRequest(boolean allowWorkerChoice, boolean workerPricingEnabled) {
    }
}
