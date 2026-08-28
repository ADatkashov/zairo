package com.zairo.factory.platforminsights;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

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
                        + "subscription revenue only, deliberately NOT booking payment volume (GMV): Factory's "
                        + "monetization is subscription-only, it takes no commission on bookings, so mixing the "
                        + "two on one tile would misrepresent platform revenue.")
                BigDecimal mrr,
                @Schema(description = "Null if there were no succeeded charges this month — nothing to report a currency for.")
                String currency) {
        }
    }
}
