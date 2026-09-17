package com.zairo.factory.loyalty;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The scheduled side of point/redemption expiration (Phase 8) -- runs
 * once a day (loyalty points expiring an hour early or late is harmless;
 * see {@code subscriptions.SubscriptionRenewalJob}'s own once-a-day
 * cadence for the same reasoning, unlike booking's minute-level jobs).
 * Processes lots in bounded pages ordered by {@code expires_at} (indexed,
 * see V57) rather than scanning every account's full history -- Phase 23.
 */
@Component
class LoyaltyExpirationJob {

    private static final Logger log = LoggerFactory.getLogger(LoyaltyExpirationJob.class);
    private static final int PAGE_SIZE = 200;

    private final LoyaltyEarnLotRepository earnLotRepository;
    private final LoyaltyLedgerService ledgerService;
    private final LoyaltyRedemptionService redemptionService;
    private final Clock clock;

    LoyaltyExpirationJob(LoyaltyEarnLotRepository earnLotRepository, LoyaltyLedgerService ledgerService,
            LoyaltyRedemptionService redemptionService, Clock clock) {
        this.earnLotRepository = earnLotRepository;
        this.ledgerService = ledgerService;
        this.redemptionService = redemptionService;
        this.clock = clock;
    }

    @Scheduled(cron = "0 0 3 * * *")
    void run() {
        int expiredPoints = expireDuePoints();
        int expiredRedemptions = redemptionService.expireDueRedemptions();
        if (expiredPoints > 0 || expiredRedemptions > 0) {
            log.info("Loyalty expiration sweep: expired {} points across due lots, {} unused redemption codes",
                    expiredPoints, expiredRedemptions);
        }
    }

    private int expireDuePoints() {
        Instant now = clock.instant();
        int totalExpired = 0;
        List<LoyaltyEarnLot> page;
        boolean progressed;
        do {
            page = earnLotRepository.findByExpiresAtBeforeAndPointsRemainingGreaterThanOrderByExpiresAtAsc(now, 0,
                    PageRequest.of(0, PAGE_SIZE));
            progressed = false;
            for (LoyaltyEarnLot lot : page) {
                try {
                    totalExpired += ledgerService.expireLot(lot.getId());
                    progressed = true;
                } catch (RuntimeException e) {
                    log.error("Failed to expire loyalty earn lot {}: {}", lot.getId(), e.getMessage(), e);
                }
            }
            // Re-query each pass instead of paging by offset: every successfully
            // expired lot's pointsRemaining drops to 0 and drops out of the
            // predicate, so page 0 always reflects what's still actually due --
            // no risk of skipping/repeating rows the way offset-based paging
            // would if earlier rows are removed from the result set mid-sweep.
            // `progressed` guards against looping forever on a lot that keeps
            // failing for the same reason every retry.
        } while (!page.isEmpty() && progressed);
        return totalExpired;
    }
}
