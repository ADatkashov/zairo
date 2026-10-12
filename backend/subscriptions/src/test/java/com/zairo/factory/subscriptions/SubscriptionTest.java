package com.zairo.factory.subscriptions;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit test of the Subscription lifecycle -- no Spring context, no database. */
class SubscriptionTest {

    private static final Instant T0 = Instant.parse("2026-10-01T00:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-20T00:00:00Z");

    private static Subscription freshFree() {
        return new Subscription(UUID.randomUUID(), UUID.randomUUID(), T0);
    }

    private static Subscription pro() {
        Subscription s = freshFree();
        s.markUpgradedToPro(T0);
        return s;
    }

    @Test
    void newSubscriptionIsAnActiveFreePlanForThirtyDays() {
        Subscription s = freshFree();

        assertThat(s.getPlan()).isEqualTo(SubscriptionPlan.FREE);
        assertThat(s.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        assertThat(s.getCurrentPeriodStart()).isEqualTo(T0);
        assertThat(s.getCurrentPeriodEnd()).isEqualTo(T0.plus(30, ChronoUnit.DAYS));
        assertThat(s.isCancelAtPeriodEnd()).isFalse();
        assertThat(s.getGracePeriodEndsAt()).isNull();
    }

    @Test
    void upgradeToProStartsAFreshPeriodAndClearsPendingDowngradeAndGrace() {
        Subscription s = freshFree();
        s.markPastDue(T0, T0.plus(3, ChronoUnit.DAYS));

        s.markUpgradedToPro(T1);

        assertThat(s.getPlan()).isEqualTo(SubscriptionPlan.PRO);
        assertThat(s.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        assertThat(s.getCurrentPeriodStart()).isEqualTo(T1);
        assertThat(s.getCurrentPeriodEnd()).isEqualTo(T1.plus(30, ChronoUnit.DAYS));
        assertThat(s.getGracePeriodEndsAt()).isNull();
        assertThat(s.isCancelAtPeriodEnd()).isFalse();
    }

    @Test
    void downgradeRequestIsIgnoredOnTheFreePlan() {
        Subscription s = freshFree();

        s.requestDowngradeAtPeriodEnd(T1);

        assertThat(s.isCancelAtPeriodEnd()).isFalse();
        assertThat(s.getUpdatedAt()).isEqualTo(T0);
    }

    @Test
    void downgradeRequestOnProIsKeptUntilClearedAndKeepsProMeanwhile() {
        Subscription s = pro();

        s.requestDowngradeAtPeriodEnd(T1);
        assertThat(s.isCancelAtPeriodEnd()).isTrue();
        assertThat(s.getPlan()).isEqualTo(SubscriptionPlan.PRO);

        s.clearDowngradeRequest(T1);
        assertThat(s.isCancelAtPeriodEnd()).isFalse();
    }

    @Test
    void renewalStartsANewPeriodAndClearsGrace() {
        Subscription s = pro();
        s.markPastDue(T0, T0.plus(3, ChronoUnit.DAYS));

        s.markRenewed(T1);

        assertThat(s.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        assertThat(s.getCurrentPeriodStart()).isEqualTo(T1);
        assertThat(s.getCurrentPeriodEnd()).isEqualTo(T1.plus(30, ChronoUnit.DAYS));
        assertThat(s.getGracePeriodEndsAt()).isNull();
        assertThat(s.getPlan()).isEqualTo(SubscriptionPlan.PRO);
    }

    @Test
    void pastDueSetsTheGraceDeadlineOnlyTheFirstTime() {
        Subscription s = pro();
        Instant firstDeadline = T0.plus(3, ChronoUnit.DAYS);

        s.markPastDue(T0, firstDeadline);
        s.markPastDue(T1, T1.plus(3, ChronoUnit.DAYS));

        assertThat(s.getStatus()).isEqualTo(SubscriptionStatus.PAST_DUE);
        assertThat(s.getGracePeriodEndsAt()).isEqualTo(firstDeadline);
        assertThat(s.getUpdatedAt()).isEqualTo(T1);
    }

    @Test
    void downgradeToFreeResetsEverythingToAFreshActiveFreePeriod() {
        Subscription s = pro();
        s.requestDowngradeAtPeriodEnd(T0);
        s.markPastDue(T0, T0.plus(3, ChronoUnit.DAYS));

        s.downgradeToFree(T1);

        assertThat(s.getPlan()).isEqualTo(SubscriptionPlan.FREE);
        assertThat(s.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        assertThat(s.getCurrentPeriodStart()).isEqualTo(T1);
        assertThat(s.getCurrentPeriodEnd()).isEqualTo(T1.plus(30, ChronoUnit.DAYS));
        assertThat(s.getGracePeriodEndsAt()).isNull();
        assertThat(s.isCancelAtPeriodEnd()).isFalse();
    }
}
