package com.zairo.factory.workforce;

import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Every 30 minutes: warn owners about appointments their worker hasn't accepted shortly before the visit. */
@Component
class WorkerUnacceptedWarningJob {

    private static final Logger log = LoggerFactory.getLogger(WorkerUnacceptedWarningJob.class);

    private final WorkerUnacceptedWarningService service;

    WorkerUnacceptedWarningJob(WorkerUnacceptedWarningService service) {
        this.service = service;
    }

    @Scheduled(fixedDelayString = "${workforce.unaccepted-warning-delay-ms:1800000}")
    void run() {
        try {
            int warned = service.warnDue(Instant.now());
            if (warned > 0) {
                log.info("Warned owners about {} unaccepted appointments", warned);
            }
        } catch (RuntimeException e) {
            log.warn("Unaccepted-appointment warning failed", e);
        }
    }
}
