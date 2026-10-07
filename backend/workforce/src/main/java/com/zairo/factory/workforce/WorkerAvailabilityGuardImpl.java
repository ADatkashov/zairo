package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.SlotNotAvailableException;
import com.zairo.factory.booking.WorkerAvailabilityGuard;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * The rules that keep a customer from ever being booked with someone who can't actually serve them:
 * <ul>
 *   <li>the person is active and works at the slot's business;</li>
 *   <li>the business allows choosing a specific person (unless the system itself is assigning one);</li>
 *   <li>a person with their own schedule is only bookable on their own slots, never on the shared ones;</li>
 *   <li>the person isn't on time off at that time;</li>
 *   <li>the person isn't already booked at that time — in this business <em>or any other</em> (the same human is
 *       one {@code user_id} across businesses). Concurrent attempts are serialized per person, so two bookings that
 *       race for the same minute can't both pass.</li>
 * </ul>
 * Working in several places is never forbidden; only the same minute can't be sold twice.
 */
@Component
class WorkerAvailabilityGuardImpl implements WorkerAvailabilityGuard {

    private final WorkerCatalog catalog;
    private final WorkerScheduleRepository scheduleRepository;
    private final WorkerTimeOffRepository timeOffRepository;
    private final WorkforceSettingsService settingsService;
    private final WorkerBookings workerBookings;
    private final PersonLock personLock;

    WorkerAvailabilityGuardImpl(WorkerCatalog catalog, WorkerScheduleRepository scheduleRepository,
            WorkerTimeOffRepository timeOffRepository, WorkforceSettingsService settingsService,
            WorkerBookings workerBookings, PersonLock personLock) {
        this.catalog = catalog;
        this.scheduleRepository = scheduleRepository;
        this.timeOffRepository = timeOffRepository;
        this.settingsService = settingsService;
        this.workerBookings = workerBookings;
        this.personLock = personLock;
    }

    @Override
    public void requireBookable(UUID workerId, AvailabilitySlot slot, UUID customerUserId) {
        Worker worker = catalog.find(workerId).orElse(null);
        if (worker == null) {
            return; // not one of ours — the directory's own checks already decide
        }
        if (!worker.active()) {
            throw new SlotNotAvailableException("This person is no longer taking bookings");
        }
        if (!worker.providerId().equals(slot.getProviderId())) {
            throw new SlotNotAvailableException("This person doesn't work at the business of this time slot");
        }
        if (!WorkerAssignmentContext.isAssigning() && !settingsService.allowsWorkerChoice(worker.providerId())) {
            throw new SlotNotAvailableException("This business doesn't take bookings for a specific person");
        }
        if (slot.getEmployeeId() == null && scheduleRepository.existsById(workerId)) {
            throw new SlotNotAvailableException("This person can only be booked at their own times");
        }
        Instant from = slot.getStartsAt();
        Instant to = slot.getEndsAt();
        if (timeOffRepository.findByWorkerIdAndEndsAtAfterOrderByStartsAt(workerId, from).stream()
                .anyMatch(t -> t.overlaps(from, to))) {
            throw new SlotNotAvailableException("This person is not available at that time");
        }

        // One lock per human: a second booking for the same person waits for the first to commit, then sees it.
        personLock.acquire(worker);
        List<Worker> samePerson = worker.userId() == null ? List.of(worker) : catalog.findByUserId(worker.userId());
        for (Worker w : samePerson) {
            if (!workerBookings.activeOverlapping(w, from, to).isEmpty()) {
                throw new SlotNotAvailableException("This person is already booked at that time");
            }
        }
    }
}
