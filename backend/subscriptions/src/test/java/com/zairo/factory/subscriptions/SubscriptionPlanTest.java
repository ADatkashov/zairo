package com.zairo.factory.subscriptions;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** Pins the plan limits: they are a product decision, so changing one should be a deliberate edit here too. */
class SubscriptionPlanTest {

    @Test
    void freePlanIsFreeAndLimited() {
        SubscriptionPlan free = SubscriptionPlan.FREE;

        assertThat(free.maxProviders).isEqualTo(1);
        assertThat(free.maxStaffPerProvider).isEqualTo(3);
        assertThat(free.maxBookingsPerMonth).isEqualTo(30);
        assertThat(free.recurringScheduleAllowed).isFalse();
        assertThat(free.monthlyPrice).isNull();
    }

    @Test
    void proPlanIsPaidAndAllowsRecurringSchedulesWithoutABookingCap() {
        SubscriptionPlan pro = SubscriptionPlan.PRO;

        assertThat(pro.maxProviders).isEqualTo(5);
        assertThat(pro.maxStaffPerProvider).isEqualTo(20);
        assertThat(pro.maxBookingsPerMonth).isEqualTo(Integer.MAX_VALUE);
        assertThat(pro.recurringScheduleAllowed).isTrue();
        assertThat(pro.monthlyPrice).isEqualByComparingTo("29.00");
    }

    @Test
    void proIsStrictlyMoreGenerousThanFree() {
        assertThat(SubscriptionPlan.PRO.maxProviders).isGreaterThan(SubscriptionPlan.FREE.maxProviders);
        assertThat(SubscriptionPlan.PRO.maxStaffPerProvider)
                .isGreaterThan(SubscriptionPlan.FREE.maxStaffPerProvider);
        assertThat(SubscriptionPlan.PRO.maxBookingsPerMonth)
                .isGreaterThan(SubscriptionPlan.FREE.maxBookingsPerMonth);
    }
}
