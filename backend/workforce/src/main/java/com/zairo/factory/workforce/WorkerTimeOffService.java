package com.zairo.factory.workforce;

import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffCreatedResponse;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffRequest;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * "The master isn't in": closes a worker's availability for a period. It never cancels anything — appointments
 * already booked inside the period are reported back to the caller, and what happens to each is the owner's call.
 *
 * <p>Both the owner and the worker may create time off (a worker reporting sick must be able to stop new bookings
 * immediately), but only the owner may remove it: a worker can only ever <em>reduce</em> their own availability.
 */
@Service
public class WorkerTimeOffService {

    private final WorkerScheduleService scheduleService;
    private final WorkerCatalog catalog;
    private final WorkerTimeOffRepository timeOffRepository;
    private final WorkerScheduleRepository scheduleRepository;
    private final WorkerSlotGenerator generator;
    private final WorkerBookings workerBookings;
    private final ApplicationEventPublisher eventPublisher;

    public WorkerTimeOffService(WorkerScheduleService scheduleService, WorkerCatalog catalog,
            WorkerTimeOffRepository timeOffRepository, WorkerScheduleRepository scheduleRepository,
            WorkerSlotGenerator generator, WorkerBookings workerBookings, ApplicationEventPublisher eventPublisher) {
        this.scheduleService = scheduleService;
        this.catalog = catalog;
        this.timeOffRepository = timeOffRepository;
        this.scheduleRepository = scheduleRepository;
        this.generator = generator;
        this.workerBookings = workerBookings;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public TimeOffCreatedResponse createByOwner(UUID providerId, UUID workerId, UUID ownerId, TimeOffRequest request) {
        Worker worker = scheduleService.requireOwnerOfWorker(providerId, workerId, ownerId);
        return create(worker, ownerId, request, false);
    }

    /** A worker closing their own availability (e.g. "I'm sick today"). */
    @Transactional
    public TimeOffCreatedResponse createByWorker(UUID workerId, UUID userId, TimeOffRequest request) {
        Worker worker = catalog.find(workerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + workerId));
        if (!userId.equals(worker.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "This is not your profile");
        }
        if (!worker.active()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Your profile is deactivated");
        }
        TimeOffCreatedResponse created = create(worker, userId, request, true);
        eventPublisher.publishEvent(new WorkerUnavailableEvent(worker.id(), worker.providerId(),
                worker.displayName(), request.startsAt(), request.endsAt(), created.affectedAppointments()));
        return created;
    }

    @Transactional(readOnly = true)
    public List<TimeOffResponse> list(UUID providerId, UUID workerId, UUID ownerId) {
        Worker worker = scheduleService.requireOwnerOfWorker(providerId, workerId, ownerId);
        return upcoming(worker);
    }

    @Transactional(readOnly = true)
    public List<TimeOffResponse> listOwn(UUID workerId, UUID userId) {
        Worker worker = catalog.find(workerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + workerId));
        if (!userId.equals(worker.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "This is not your profile");
        }
        return upcoming(worker);
    }

    /** Owner-only: the worker is available again. */
    @Transactional
    public void delete(UUID providerId, UUID timeOffId, UUID ownerId) {
        WorkerTimeOff timeOff = timeOffRepository.findById(timeOffId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + timeOffId));
        scheduleService.requireOwnerOfWorker(providerId, timeOff.getWorkerId(), ownerId);
        timeOffRepository.delete(timeOff);
        timeOffRepository.flush();
        regenerateIfScheduled(timeOff.getWorkerId());
    }

    private TimeOffCreatedResponse create(Worker worker, UUID createdBy, TimeOffRequest request, boolean byWorker) {
        if (!request.startsAt().isBefore(request.endsAt())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "startsAt must be before endsAt");
        }
        if (!request.endsAt().isAfter(Instant.now())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The period is already over");
        }
        String reason = request.reason() == null || request.reason().isBlank() ? null : request.reason().trim();
        WorkerTimeOff saved = timeOffRepository.save(new WorkerTimeOff(UUID.randomUUID(), worker.id(),
                worker.providerId(), request.startsAt(), request.endsAt(), reason, createdBy, Instant.now()));
        timeOffRepository.flush();
        regenerateIfScheduled(worker.id());
        int affected = workerBookings.activeOverlapping(worker, request.startsAt(), request.endsAt()).size();
        return new TimeOffCreatedResponse(toResponse(saved, worker), affected);
    }

    private void regenerateIfScheduled(UUID workerId) {
        if (scheduleRepository.existsById(workerId)) {
            generator.regenerate(workerId);
        }
    }

    private List<TimeOffResponse> upcoming(Worker worker) {
        return timeOffRepository.findByWorkerIdAndEndsAtAfterOrderByStartsAt(worker.id(), Instant.now()).stream()
                .map(t -> toResponse(t, worker)).toList();
    }

    private static TimeOffResponse toResponse(WorkerTimeOff t, Worker worker) {
        return new TimeOffResponse(t.getId(), t.getWorkerId(), t.getStartsAt(), t.getEndsAt(), t.getReason(),
                worker.userId() != null && worker.userId().equals(t.getCreatedBy()));
    }
}
