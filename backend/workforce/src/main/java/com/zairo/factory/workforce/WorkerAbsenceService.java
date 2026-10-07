package com.zairo.factory.workforce;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * What happens to booked appointments when their person can't make it. A customer who said "any master" doesn't
 * care who serves them, so those are handed to a free colleague straight away (the customer is only told). A
 * customer who chose a specific person is never swapped silently: those stay in the owner's "needs a decision" list.
 *
 * <p>Deliberately not transactional itself: each hand-over runs in its own transaction, so one that can't be done
 * (nobody free) never blocks the rest or rolls back the time off that triggered it.
 */
@Service
public class WorkerAbsenceService {

    private static final Logger log = LoggerFactory.getLogger(WorkerAbsenceService.class);

    private final WorkerBookings workerBookings;
    private final WorkerBookingStateRepository stateRepository;
    private final WorkerReassignmentService reassignmentService;

    public WorkerAbsenceService(WorkerBookings workerBookings, WorkerBookingStateRepository stateRepository,
            WorkerReassignmentService reassignmentService) {
        this.workerBookings = workerBookings;
        this.stateRepository = stateRepository;
        this.reassignmentService = reassignmentService;
    }

    /**
     * Re-assigns every "any master" appointment of {@code worker} inside [from, to).
     *
     * @return how many appointments in the period still need the owner (named person, or nobody free)
     */
    public int handleAbsence(Worker worker, Instant from, Instant to) {
        int left = 0;
        List<WorkerBookings.ActiveBooking> affected = workerBookings.activeOverlapping(worker, from, to);
        for (WorkerBookings.ActiveBooking ab : affected) {
            if (!autoReassignIfAny(ab.booking().getId())) {
                left++;
            }
        }
        return left;
    }

    /** @return true when the appointment was "any master" and was handed to someone else. */
    public boolean autoReassignIfAny(UUID bookingId) {
        WorkerBookingState state = stateRepository.findById(bookingId).orElse(null);
        if (state == null || state.getPreference() != WorkerBookingState.Preference.ANY) {
            return false;
        }
        try {
            return reassignmentService.tryAutoReassign(bookingId);
        } catch (RuntimeException e) {
            log.warn("Couldn't re-assign appointment {} automatically; it stays for the owner", bookingId, e);
            return false;
        }
    }
}
