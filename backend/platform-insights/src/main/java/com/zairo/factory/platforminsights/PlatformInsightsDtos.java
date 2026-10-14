package com.zairo.factory.platforminsights;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public final class PlatformInsightsDtos {

    private PlatformInsightsDtos() {
    }

    public record PlatformDashboardMetrics(
            UsersSection users,
            BusinessesSection businesses,
            SubscriptionsSection subscriptions,
            BookingsSection bookings,
            PaymentsSection payments,
            RevenueSection revenue) {

        public record UsersSection(@Schema(description = "Every registered account, any role.") long total) {
        }

        public record BusinessesSection(long total, long active, long pendingModeration, long blocked) {
        }

        public record SubscriptionsSection(long free, long pro, long active, long pastDue, long cancelled) {
        }

        public record BookingsSection(
                @Schema(description = "Created since the start of today (UTC).") long today,
                @Schema(description = "Created since the start of this week (UTC, Monday).") long thisWeek,
                @Schema(description = "Created since the start of this month (UTC).") long thisMonth,
                long completed, long cancelled) {
        }

        public record PaymentsSection(long succeeded, long failed, long pending, long refunded,
                @Schema(description = "See GET /api/v1/platform/payments/failed-refunds for the actual list.")
                long refundFailed) {
        }

        public record RevenueSection(
                @Schema(description = "SUM of succeeded SubscriptionCharge.amount this calendar month (UTC) — "
                        + "subscription revenue, kept on its own tile rather than merged with platformCommission "
                        + "below: they're two independent revenue lines (see ADR-0007), and GMV (sum of all "
                        + "booking Payment.amount) is a marketplace-health metric, not revenue on either tile.")
                BigDecimal mrr,
                @Schema(description = "Null if there were no succeeded charges this month — nothing to report a currency for.")
                String currency,
                @Schema(description = "SUM of PaymentAllocation.platformFee this calendar month (UTC) — ZAIRO's "
                        + "marketplace commission on booking payments (see ADR-0007/CommissionCalculator). "
                        + "Introduced 2026-09-19 — Factory's monetization was subscription-only before that; see "
                        + "docs/PRODUCT_PRODUCTION_ROADMAP.md section 9 for the superseded statement.")
                BigDecimal platformCommission,
                @Schema(description = "Null if there were no payment allocations this month — nothing to report a currency for.")
                String platformCommissionCurrency) {
        }
    }

    /** Recent history behind the dashboard's trend lines — oldest day first, every day present (zero-filled). */
    public record PlatformTrends(
            @Schema(description = "Bookings created per UTC day, oldest first, one entry per day in the window.")
            List<DailyCount> bookingsCreated) {

        public record DailyCount(LocalDate date, long count) {
        }
    }
}
