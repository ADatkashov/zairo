package com.zairo.factory.loyalty;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Hourly sweep that grants today's birthday bonuses. Hourly rather than once a day on purpose: the award is
 * idempotent per (member, year) (see {@link LoyaltyBirthdayService}), so a restart or an outage never makes a member
 * miss their birthday -- the next run catches up -- and several app instances running it at once can't double-award.
 * "Today" is the UTC date.
 */
@Component
class LoyaltyBirthdayJob {

    private static final Logger log = LoggerFactory.getLogger(LoyaltyBirthdayJob.class);

    private final LoyaltyBirthdayService birthdayService;
    private final Clock clock;

    LoyaltyBirthdayJob(LoyaltyBirthdayService birthdayService, Clock clock) {
        this.birthdayService = birthdayService;
        this.clock = clock;
    }

    @Scheduled(cron = "0 20 * * * *")
    void run() {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        int total = 0;
        for (LoyaltyProgram program : birthdayService.programsGrantingBirthdayBonus()) {
            try {
                for (UUID userId : birthdayService.birthdayMemberIds(program, today)) {
                    try {
                        if (birthdayService.awardOne(program, userId, today.getYear())) {
                            total++;
                        }
                    } catch (RuntimeException e) {
                        log.error("Birthday bonus failed for member {} of provider {}: {}", userId,
                                program.getProviderId(), e.getMessage(), e);
                    }
                }
            } catch (RuntimeException e) {
                log.error("Birthday bonus sweep failed for provider {}: {}", program.getProviderId(), e.getMessage(), e);
            }
        }
        if (total > 0) {
            log.info("Birthday bonus sweep: awarded {} birthday bonuses", total);
        }
    }
}
