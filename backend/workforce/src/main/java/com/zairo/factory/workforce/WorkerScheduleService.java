package com.zairo.factory.workforce;

import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.workforce.WorkerScheduleDtos.HoursInterval;
import com.zairo.factory.workforce.WorkerScheduleDtos.SaveScheduleRequest;
import com.zairo.factory.workforce.WorkerScheduleDtos.SaveScheduleResult;
import com.zairo.factory.workforce.WorkerScheduleDtos.ScheduleResponse;
import com.zairo.factory.workforce.WorkerScheduleDtos.WorkerSummaryResponse;
import java.time.DateTimeException;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * The owner's weekly schedule per worker. By design only the owner of the business can set it: workers can't be
 * trusted to keep their own schedule, and the owner is the one who answers to the customer.
 */
@Service
public class WorkerScheduleService {

    private final ProviderOwnership providerOwnership;
    private final WorkerCatalog catalog;
    private final WorkerScheduleRepository scheduleRepository;
    private final WorkerWorkHoursRepository hoursRepository;
    private final WorkerTimeOffRepository timeOffRepository;
    private final WorkerSlotGenerator generator;

    public WorkerScheduleService(ProviderOwnership providerOwnership, WorkerCatalog catalog,
            WorkerScheduleRepository scheduleRepository, WorkerWorkHoursRepository hoursRepository,
            WorkerTimeOffRepository timeOffRepository, WorkerSlotGenerator generator) {
        this.providerOwnership = providerOwnership;
        this.catalog = catalog;
        this.scheduleRepository = scheduleRepository;
        this.hoursRepository = hoursRepository;
        this.timeOffRepository = timeOffRepository;
        this.generator = generator;
    }

    /** Everyone who works at the business, with whether they have their own schedule. */
    @Transactional(readOnly = true)
    public List<WorkerSummaryResponse> workers(UUID providerId, UUID ownerId) {
        providerOwnership.requireOwner(providerId, ownerId);
        List<Worker> workers = catalog.findByProvider(providerId);
        Instant now = Instant.now();
        Map<UUID, WorkerSchedule> schedules = scheduleRepository
                .findAllById(workers.stream().map(Worker::id).toList()).stream()
                .collect(Collectors.toMap(WorkerSchedule::getWorkerId, Function.identity()));
        Map<UUID, List<WorkerTimeOff>> off = timeOffRepository
                .findByWorkerIdInAndEndsAtAfter(workers.stream().map(Worker::id).toList(), now).stream()
                .collect(Collectors.groupingBy(WorkerTimeOff::getWorkerId));
        return workers.stream().map(w -> {
            Instant offUntil = off.getOrDefault(w.id(), List.of()).stream()
                    .filter(t -> !t.getStartsAt().isAfter(now)).map(WorkerTimeOff::getEndsAt)
                    .max(Comparator.naturalOrder()).orElse(null);
            WorkerCatalog.Ranked rating = catalog.ratingOf(w, "");
            return new WorkerSummaryResponse(w.id(), w.kind(), w.displayName(), w.photoUrl(), w.active(),
                    schedules.containsKey(w.id()), offUntil,
                    rating.reviewCount() == 0 ? null : Math.round(rating.averageRating() * 10) / 10.0,
                    rating.reviewCount());
        }).toList();
    }

    @Transactional(readOnly = true)
    public ScheduleResponse get(UUID providerId, UUID workerId, UUID ownerId) {
        requireOwnerOfWorker(providerId, workerId, ownerId);
        return response(workerId);
    }

    @Transactional
    public SaveScheduleResult save(UUID providerId, UUID workerId, UUID ownerId, SaveScheduleRequest request) {
        requireOwnerOfWorker(providerId, workerId, ownerId);
        ZoneId zone = parseZone(request.zoneId());
        validateHours(request.hours());
        Instant now = Instant.now();

        WorkerSchedule schedule = scheduleRepository.findById(workerId).orElse(null);
        if (schedule == null) {
            scheduleRepository.save(new WorkerSchedule(workerId, providerId, zone.getId(), request.slotMinutes(),
                    request.breakMinutes(), now));
        } else {
            schedule.update(zone.getId(), request.slotMinutes(), request.breakMinutes(), now);
            scheduleRepository.save(schedule);
        }
        hoursRepository.deleteByWorkerId(workerId);
        hoursRepository.flush();
        hoursRepository.saveAll(request.hours().stream().map(h -> new WorkerWorkHours(UUID.randomUUID(), workerId,
                DayOfWeek.of(h.dayOfWeek()), h.startTime(), h.endTime())).toList());

        WorkerSlotGenerator.Result result = generator.regenerate(workerId);
        return new SaveScheduleResult(response(workerId), result.created(), result.removed());
    }

    /** Back to the business's shared slots: the worker's own future OPEN slots go, booked ones stay. */
    @Transactional
    public void delete(UUID providerId, UUID workerId, UUID ownerId) {
        requireOwnerOfWorker(providerId, workerId, ownerId);
        if (scheduleRepository.existsById(workerId)) {
            hoursRepository.deleteByWorkerId(workerId);
            scheduleRepository.deleteById(workerId);
            scheduleRepository.flush();
            generator.regenerate(workerId);
        }
    }

    /** The worker, once confirmed to belong to this business and its owner to be the caller. */
    Worker requireOwnerOfWorker(UUID providerId, UUID workerId, UUID ownerId) {
        providerOwnership.requireOwner(providerId, ownerId);
        Worker worker = catalog.find(workerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + workerId));
        if (!providerId.equals(worker.providerId())) {
            // Don't reveal a worker of another business.
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + workerId);
        }
        return worker;
    }

    private ScheduleResponse response(UUID workerId) {
        WorkerSchedule schedule = scheduleRepository.findById(workerId).orElse(null);
        if (schedule == null) {
            return new ScheduleResponse(workerId, false, null, null, null, List.of());
        }
        List<HoursInterval> hours = hoursRepository.findByWorkerId(workerId).stream()
                .sorted(Comparator.comparing((WorkerWorkHours h) -> h.getDayOfWeek().getValue())
                        .thenComparing(WorkerWorkHours::getStartTime))
                .map(h -> new HoursInterval(h.getDayOfWeek().getValue(), h.getStartTime(), h.getEndTime())).toList();
        return new ScheduleResponse(workerId, true, schedule.getZoneId(), schedule.getSlotMinutes(),
                schedule.getBreakMinutes(), hours);
    }

    private static ZoneId parseZone(String zoneId) {
        try {
            return ZoneId.of(zoneId);
        } catch (DateTimeException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown time zone: " + zoneId);
        }
    }

    private static void validateHours(List<HoursInterval> hours) {
        for (HoursInterval h : hours) {
            if (!h.startTime().isBefore(h.endTime())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "startTime must be before endTime (day " + h.dayOfWeek() + ")");
            }
        }
        Map<Integer, List<HoursInterval>> byDay = hours.stream().collect(Collectors.groupingBy(HoursInterval::dayOfWeek));
        for (List<HoursInterval> day : byDay.values()) {
            List<HoursInterval> sorted = day.stream().sorted(Comparator.comparing(HoursInterval::startTime)).toList();
            for (int i = 1; i < sorted.size(); i++) {
                if (sorted.get(i).startTime().isBefore(sorted.get(i - 1).endTime())) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "Working intervals overlap on day " + sorted.get(i).dayOfWeek());
                }
            }
        }
    }
}
