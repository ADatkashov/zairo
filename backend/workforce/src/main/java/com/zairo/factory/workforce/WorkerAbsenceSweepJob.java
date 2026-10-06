package com.zairo.factory.workforce;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Catches what the instant paths can't: a person deactivated in their directory (nothing publishes an event for
 * that), or a colleague who has since become free. Customers who said "any master" and whose person is off or gone
 * are handed to a free colleague; named-person appointments are left for the owner, as always.
 */
@Component
class WorkerAbsenceSweepJob {

    private static final Logger log = LoggerFactory.getLogger(WorkerAbsenceSweepJob.class);
    private static final Duration HORIZON = Duration.ofDays(120);

    private final WorkerCatalog catalog;
    private final WorkerTimeOffRepository timeOffRepository;
    private final WorkerBookings workerBookings;
    private final WorkerAbsenceService absenceService;

    WorkerAbsenceSweepJob(WorkerCatalog catalog, WorkerTimeOffRepository timeOffRepository,
            WorkerBookings workerBookings, WorkerAbsenceService absenceService) {
        this.catalog = catalog;
        this.timeOffRepository = timeOffRepository;
        this.workerBookings = workerBookings;
        this.absenceService = absenceService;
    }

    @Scheduled(cron = "${workforce.absence-sweep-cron:0 40 3 * * *}")
    void sweep() {
        sweepNow();
    }

    /** In-package so a test can drive it instead of waiting for the cron. @return how many appointments it handed over. */
    int sweepNow() {
        Instant now = Instant.now();
        int handedOver = 0;
        try {
            for (Worker gone : catalog.findInactive()) {
                for (WorkerBookings.ActiveBooking ab : workerBookings.activeOverlapping(gone, now,
                        now.plus(HORIZON))) {
                    handedOver += handle(ab.booking().getId());
                }
            }
            for (WorkerTimeOff off : timeOffRepository.findByEndsAtAfter(now)) {
                Worker worker = catalog.find(off.getWorkerId()).orElse(null);
                if (worker == null) {
                    continue;
                }
                for (WorkerBookings.ActiveBooking ab : workerBookings.activeOverlapping(worker, off.getStartsAt(),
                        off.getEndsAt())) {
                    handedOver += handle(ab.booking().getId());
                }
            }
        } catch (RuntimeException e) {
            log.warn("The absence sweep stopped early", e);
        }
        return handedOver;
    }

    private int handle(UUID bookingId) {
        return absenceService.autoReassignIfAny(bookingId) ? 1 : 0;
    }
}
