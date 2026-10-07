package com.zairo.factory.workforce;

import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Keeps every scheduled worker's slots topped up to the rolling horizon (a worker's slots only extend as far as
 * the last run, so without this the calendar would run dry after {@link WorkerSlotGenerator#HORIZON_DAYS} days).
 * One worker failing never stops the others.
 */
@Component
class WorkerSlotRefreshJob {

    private static final Logger log = LoggerFactory.getLogger(WorkerSlotRefreshJob.class);

    private final WorkerScheduleRepository scheduleRepository;
    private final WorkerSlotGenerator generator;

    WorkerSlotRefreshJob(WorkerScheduleRepository scheduleRepository, WorkerSlotGenerator generator) {
        this.scheduleRepository = scheduleRepository;
        this.generator = generator;
    }

    @Scheduled(cron = "${workforce.slot-refresh-cron:0 20 3 * * *}")
    void refreshAll() {
        refreshAllNow();
    }

    /** Public-in-package so a test can drive it instead of waiting for the cron. */
    int refreshAllNow() {
        List<UUID> workerIds = scheduleRepository.findAll().stream().map(WorkerSchedule::getWorkerId).toList();
        int ok = 0;
        for (UUID workerId : workerIds) {
            try {
                generator.regenerate(workerId);
                ok++;
            } catch (RuntimeException e) {
                log.warn("Couldn't refresh the slots of worker {}", workerId, e);
            }
        }
        return ok;
    }
}
