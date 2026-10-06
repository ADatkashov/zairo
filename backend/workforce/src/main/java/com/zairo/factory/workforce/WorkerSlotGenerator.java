package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Turns a worker's owner-defined weekly schedule into real {@link AvailabilitySlot} rows (with
 * {@code employee_id = worker}) for the next {@value #HORIZON_DAYS} days — so the owner edits one template instead
 * of creating slots by hand for every person, while booking keeps its existing atomic slot claim.
 *
 * <p>Idempotent and safe to re-run at any time (a schedule edit, time off, the daily refresh): it only ever
 * removes {@code OPEN} future slots that no longer belong, adds the missing ones, and never touches a slot that is
 * booked.
 */
@Component
public class WorkerSlotGenerator {

    public static final int HORIZON_DAYS = 28;

    /** What one run did. */
    public record Result(int created, int removed) {
    }

    private final WorkerCatalog catalog;
    private final WorkerScheduleRepository scheduleRepository;
    private final WorkerWorkHoursRepository hoursRepository;
    private final WorkerTimeOffRepository timeOffRepository;
    private final AvailabilitySlotRepository slotRepository;
    private final JdbcClient jdbc;

    public WorkerSlotGenerator(WorkerCatalog catalog, WorkerScheduleRepository scheduleRepository,
            WorkerWorkHoursRepository hoursRepository, WorkerTimeOffRepository timeOffRepository,
            AvailabilitySlotRepository slotRepository, JdbcClient jdbc) {
        this.catalog = catalog;
        this.scheduleRepository = scheduleRepository;
        this.hoursRepository = hoursRepository;
        this.timeOffRepository = timeOffRepository;
        this.slotRepository = slotRepository;
        this.jdbc = jdbc;
    }

    @Transactional
    public Result regenerate(UUID workerId) {
        // Two regenerations of the same worker (an edit racing the daily refresh) must not interleave.
        jdbc.sql("select pg_advisory_xact_lock(hashtext(:key))").param("key", "worker-slots:" + workerId)
                .query((rs, n) -> 1).list();

        Optional<Worker> workerOpt = catalog.find(workerId);
        if (workerOpt.isEmpty()) {
            return new Result(0, 0);
        }
        Worker worker = workerOpt.get();
        Instant now = Instant.now();

        List<AvailabilitySlot> future = slotRepository.findByProviderIdAndEmployeeId(worker.providerId(), workerId)
                .stream().filter(s -> !s.getStartsAt().isBefore(now)).toList();
        List<AvailabilitySlot> open = future.stream().filter(s -> s.getStatus() == AvailabilityStatus.OPEN).toList();
        List<AvailabilitySlot> taken = future.stream().filter(s -> s.getStatus() != AvailabilityStatus.OPEN).toList();

        Optional<WorkerSchedule> schedule = scheduleRepository.findById(workerId);
        List<Instant[]> candidates = schedule.isPresent() && worker.active()
                ? candidates(schedule.get(), hoursRepository.findByWorkerId(workerId),
                        timeOffRepository.findByWorkerIdAndEndsAtAfterOrderByStartsAt(workerId, now), taken, now)
                : List.of();

        Set<String> wanted = candidates.stream().map(WorkerSlotGenerator::key).collect(Collectors.toSet());
        Set<String> present = open.stream().map(s -> key(new Instant[] {s.getStartsAt(), s.getEndsAt()}))
                .collect(Collectors.toSet());

        List<AvailabilitySlot> toDelete = open.stream()
                .filter(s -> !wanted.contains(key(new Instant[] {s.getStartsAt(), s.getEndsAt()}))).toList();
        List<AvailabilitySlot> toCreate = new ArrayList<>();
        for (Instant[] c : candidates) {
            if (!present.contains(key(c))) {
                toCreate.add(new AvailabilitySlot(UUID.randomUUID(), worker.providerId(), c[0], c[1],
                        AvailabilityStatus.OPEN, workerId));
            }
        }
        slotRepository.deleteAll(toDelete);
        slotRepository.saveAll(toCreate);
        return new Result(toCreate.size(), toDelete.size());
    }

    private List<Instant[]> candidates(WorkerSchedule schedule, List<WorkerWorkHours> hours,
            List<WorkerTimeOff> timeOff, List<AvailabilitySlot> taken, Instant now) {
        ZoneId zone = ZoneId.of(schedule.getZoneId());
        LocalDate today = LocalDate.ofInstant(now, zone);
        List<Instant[]> result = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (int d = 0; d < HORIZON_DAYS; d++) {
            LocalDate date = today.plusDays(d);
            List<WorkerWorkHours> dayHours = hours.stream().filter(h -> h.getDayOfWeek() == date.getDayOfWeek())
                    .sorted(Comparator.comparing(WorkerWorkHours::getStartTime)).toList();
            for (WorkerWorkHours interval : dayHours) {
                LocalTime cursor = interval.getStartTime();
                while (true) {
                    LocalTime end = cursor.plusMinutes(schedule.getSlotMinutes());
                    // isBefore(cursor) catches wrapping past midnight.
                    if (end.isAfter(interval.getEndTime()) || end.isBefore(cursor)) {
                        break;
                    }
                    Instant start = ZonedDateTime.of(date, cursor, zone).toInstant();
                    Instant stop = ZonedDateTime.of(date, end, zone).toInstant();
                    boolean future = !start.isBefore(now);
                    boolean off = timeOff.stream().anyMatch(t -> t.overlaps(start, stop));
                    boolean clash = taken.stream()
                            .anyMatch(s -> s.getStartsAt().isBefore(stop) && s.getEndsAt().isAfter(start));
                    Instant[] candidate = {start, stop};
                    if (future && !off && !clash && seen.add(key(candidate))) {
                        result.add(candidate);
                    }
                    LocalTime next = end.plusMinutes(schedule.getBreakMinutes());
                    if (next.isBefore(end)) {
                        break;
                    }
                    cursor = next;
                }
            }
        }
        return result;
    }

    private static String key(Instant[] window) {
        return window[0].toEpochMilli() + "-" + window[1].toEpochMilli();
    }
}
