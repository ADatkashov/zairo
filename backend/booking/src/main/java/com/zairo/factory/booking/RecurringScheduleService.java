package com.zairo.factory.booking;

import com.zairo.factory.booking.AvailabilitySlotDtos.AvailabilitySlotResponse;
import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleResult;
import java.time.DateTimeException;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Generates real {@link AvailabilitySlot} rows from a weekly pattern (e.g.
 * "Tue/Wed/Thu 10:00-18:00, 30min slots, 10min break") instead of the owner
 * creating each slot by hand. Never deletes or overwrites an existing slot —
 * a candidate that would overlap one (any status, OPEN or BOOKED) is simply
 * skipped, both to honor "don't touch existing slots without an explicit
 * action" and, as a side effect, to make re-running the same schedule twice
 * safe: the second run's candidates all conflict with the first run's
 * already-persisted slots and get skipped too, rather than duplicating them.
 */
@Service
public class RecurringScheduleService {

    /**
     * A real guard, not an arbitrary enterprise limit: nothing stops an
     * owner from typing a range of years by mistake, which would otherwise
     * silently generate thousands of rows in one request.
     */
    private static final int MAX_RANGE_DAYS = 92;

    private final AvailabilitySlotRepository availabilitySlotRepository;

    public RecurringScheduleService(AvailabilitySlotRepository availabilitySlotRepository) {
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    @Transactional
    public RecurringScheduleResult generate(UUID providerId, RecurringScheduleRequest request) {
        validate(request);
        ZoneId zone = parseZone(request.zoneId());
        Set<DayOfWeek> daysOfWeek = new HashSet<>(request.daysOfWeek());
        List<LocalDate> holidays = request.holidays() == null ? List.of() : request.holidays();

        List<Instant[]> candidates = new ArrayList<>();
        for (LocalDate date = request.rangeStart(); !date.isAfter(request.rangeEnd()); date = date.plusDays(1)) {
            if (!daysOfWeek.contains(date.getDayOfWeek()) || holidays.contains(date)) {
                continue;
            }
            candidates.addAll(dayWindows(date, request, zone));
        }

        if (candidates.isEmpty()) {
            return new RecurringScheduleResult(List.of(), 0);
        }

        // One query for the whole affected window, not one per candidate —
        // same batched-lookup shape as ReviewSummaryService.
        Instant windowStart = candidates.get(0)[0];
        Instant windowEnd = candidates.get(candidates.size() - 1)[1];
        List<AvailabilitySlot> existing = availabilitySlotRepository
                .findByProviderIdAndStartsAtLessThanAndEndsAtGreaterThan(providerId, windowEnd, windowStart);

        List<AvailabilitySlot> toSave = new ArrayList<>();
        int skipped = 0;
        for (Instant[] candidate : candidates) {
            Instant start = candidate[0];
            Instant end = candidate[1];
            boolean conflicts = existing.stream()
                    .anyMatch(slot -> slot.getStartsAt().isBefore(end) && slot.getEndsAt().isAfter(start));
            if (conflicts) {
                skipped++;
                continue;
            }
            toSave.add(new AvailabilitySlot(UUID.randomUUID(), providerId, start, end, AvailabilityStatus.OPEN));
        }

        List<AvailabilitySlot> saved = availabilitySlotRepository.saveAll(toSave);
        return new RecurringScheduleResult(saved.stream().map(AvailabilitySlotResponse::from).toList(), skipped);
    }

    /** One day's worth of back-to-back [start, start+duration) windows, stopping once a slot wouldn't fit before endTime. */
    private List<Instant[]> dayWindows(LocalDate date, RecurringScheduleRequest request, ZoneId zone) {
        List<Instant[]> windows = new ArrayList<>();
        LocalTime cursor = request.startTime();
        while (true) {
            LocalTime slotEnd = cursor.plusMinutes(request.slotDurationMinutes());
            // isBefore(cursor) catches LocalTime wrapping past midnight —
            // only reachable with a nonsensical duration, guarded here
            // rather than trusted away.
            if (slotEnd.isAfter(request.endTime()) || slotEnd.isBefore(cursor)) {
                break;
            }
            windows.add(new Instant[] {ZonedDateTime.of(date, cursor, zone).toInstant(),
                    ZonedDateTime.of(date, slotEnd, zone).toInstant()});
            LocalTime next = slotEnd.plusMinutes(request.breakMinutes());
            if (next.isBefore(slotEnd)) {
                break;
            }
            cursor = next;
        }
        return windows;
    }

    private void validate(RecurringScheduleRequest request) {
        if (request.daysOfWeek() == null || request.daysOfWeek().isEmpty()) {
            throw new InvalidRecurringScheduleException("At least one day of week is required");
        }
        if (request.startTime() == null || request.endTime() == null
                || !request.startTime().isBefore(request.endTime())) {
            throw new InvalidRecurringScheduleException("startTime must be before endTime");
        }
        if (request.slotDurationMinutes() <= 0) {
            throw new InvalidRecurringScheduleException("slotDurationMinutes must be positive");
        }
        if (request.breakMinutes() < 0) {
            throw new InvalidRecurringScheduleException("breakMinutes cannot be negative");
        }
        if (request.rangeStart() == null || request.rangeEnd() == null
                || request.rangeStart().isAfter(request.rangeEnd())) {
            throw new InvalidRecurringScheduleException("rangeStart must not be after rangeEnd");
        }
        if (ChronoUnit.DAYS.between(request.rangeStart(), request.rangeEnd()) > MAX_RANGE_DAYS) {
            throw new InvalidRecurringScheduleException(
                    "Date range too large (max " + MAX_RANGE_DAYS + " days) — generate in smaller batches");
        }
    }

    private ZoneId parseZone(String zoneId) {
        if (zoneId == null || zoneId.isBlank()) {
            throw new InvalidRecurringScheduleException("zoneId is required");
        }
        try {
            return ZoneId.of(zoneId);
        } catch (DateTimeException e) {
            throw new InvalidRecurringScheduleException("Invalid zoneId: " + zoneId);
        }
    }
}
