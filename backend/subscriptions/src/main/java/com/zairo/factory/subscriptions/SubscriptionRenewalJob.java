package com.zairo.factory.subscriptions;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The first {@code @Scheduled} job in this codebase — see the subscriptions
 * ADR for why: everything else in this project is an explicit, on-demand
 * HTTP call, but recurring billing that depends on a human clicking a
 * button every month isn't honestly "recurring." Deliberately scoped to
 * exactly these two subscription-lifecycle checks, not a general-purpose
 * job scheduler.
 */
@Component
class SubscriptionRenewalJob {

    private final SubscriptionRenewalService subscriptionRenewalService;

    SubscriptionRenewalJob(SubscriptionRenewalService subscriptionRenewalService) {
        this.subscriptionRenewalService = subscriptionRenewalService;
    }

    /** Once a day, 03:00 UTC — low-traffic hour, and daily is frequent enough that a missed run is caught the next day. */
    @Scheduled(cron = "0 0 3 * * *")
    void renewDueSubscriptions() {
        subscriptionRenewalService.renewDueSubscriptions();
        // Same run, right after: anyone who failed on an earlier day gets another attempt today
        // (the ones that failed a moment ago are skipped — see retryPastDueSubscriptions).
        subscriptionRenewalService.retryPastDueSubscriptions();
    }

    @Scheduled(cron = "0 15 3 * * *")
    void downgradeExpiredGracePeriods() {
        subscriptionRenewalService.downgradeExpiredGracePeriods();
    }
}
