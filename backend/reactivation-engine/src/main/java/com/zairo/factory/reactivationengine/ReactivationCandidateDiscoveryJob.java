package com.zairo.factory.reactivationengine;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The time-triggered side of {@link ReactivationDiscoveryService#scanForInactiveCustomers}
 * -- runs once a day (see ADR-0005: day-granularity inactivity doesn't need
 * Rebook's hourly cadence, let alone Smart Fill's one-minute one). See that
 * method's own doc comment for what the sweep actually does; this class is
 * deliberately just the {@code @Scheduled} wrapper, nothing to test here
 * beyond it calls the service (same reasoning as {@code
 * smartfill.SmartFillCampaignJob}).
 */
@Component
class ReactivationCandidateDiscoveryJob {

    private final ReactivationDiscoveryService discoveryService;

    ReactivationCandidateDiscoveryJob(ReactivationDiscoveryService discoveryService) {
        this.discoveryService = discoveryService;
    }

    @Scheduled(fixedDelay = 86_400_000)
    void scanForInactiveCustomers() {
        discoveryService.scanForInactiveCustomers();
    }
}
