package com.zairo.factory.subscriptions;

import java.math.BigDecimal;

/**
 * Hardcoded, not a DB table — there's no admin UI to edit prices, and
 * changing one is a business decision that should go through code review,
 * not a runtime toggle. Two tiers only (see SESSION_NOTES.md / the
 * subscriptions ADR): a third tier is exactly the kind of speculative
 * complexity this project's "don't build ahead of real need" discipline
 * (ADR-0001..0004) warns against — nobody has asked for one yet, and a
 * two-entry enum is trivially extended.
 *
 * <p>{@code maxStaffPerProvider} is combined masters+mechanics, not
 * per-vertical — a given provider is only ever one vertical at a time (see
 * {@code MasterDirectoryService.isBeautyVertical} /
 * {@code MechanicDirectoryService.isAutoVertical}), so "combined" and
 * "per-vertical" are the same number in practice; combined is simpler to
 * store. {@code maxBookingsPerMonth} is aggregated across every provider the
 * owner has, not per-provider — the owner is who's paying for the plan.
 */
public enum SubscriptionPlan {

    FREE(1, 3, 30, false, null),
    PRO(5, 20, Integer.MAX_VALUE, true, new BigDecimal("29.00"));

    public final int maxProviders;
    public final int maxStaffPerProvider;
    public final int maxBookingsPerMonth;
    public final boolean recurringScheduleAllowed;
    public final BigDecimal monthlyPrice;

    SubscriptionPlan(int maxProviders, int maxStaffPerProvider, int maxBookingsPerMonth,
            boolean recurringScheduleAllowed, BigDecimal monthlyPrice) {
        this.maxProviders = maxProviders;
        this.maxStaffPerProvider = maxStaffPerProvider;
        this.maxBookingsPerMonth = maxBookingsPerMonth;
        this.recurringScheduleAllowed = recurringScheduleAllowed;
        this.monthlyPrice = monthlyPrice;
    }
}
