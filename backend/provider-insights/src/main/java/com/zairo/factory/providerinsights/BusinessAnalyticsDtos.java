package com.zairo.factory.providerinsights;

import com.zairo.factory.customerintelligence.RetentionStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * The Business Intelligence Dashboard's own response shapes — every field
 * here is composed from real Booking/Payment/AvailabilitySlot/Smart
 * Fill/Revenue Engine/Customer Intelligence data for the caller's own
 * reporting period (see {@link BusinessAnalyticsService}), never a guessed
 * or hardcoded number. Action Center items carry a type and a count only —
 * no pre-baked text — so the client renders the localized copy, matching
 * how the rest of this app's user-facing strings work.
 */
public final class BusinessAnalyticsDtos {

    private BusinessAnalyticsDtos() {
    }

    public record OverviewResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            Instant from,
            Instant to,
            @Schema(description = "Bookings whose slot starts within [from, to).") long totalBookings,
            long completedBookings,
            @Schema(description = "CONFIRMED bookings in range whose slot hasn't started yet.") long upcomingBookings,
            long cancelledBookings,
            long noShowBookings,
            double cancellationRate,
            double noShowRate,
            @Schema(description = "Sum of SUCCEEDED payments for bookings in range.") BigDecimal totalRevenue,
            BigDecimal averageBookingValue,
            String currency,
            @Schema(description = "Booked slot duration / offered slot duration in range — null if this "
                    + "provider has no availability slots starting in range, rather than a guessed number.")
            Double utilization,
            @Schema(description = "Lifetime share of this provider's customers with more than one completed "
                    + "booking — not scoped to [from, to), since a customer relationship spans the whole "
                    + "history, not just the selected period.")
            double returningCustomerRate,
            @Schema(description = "Revenue Engine's outcome ledger, decided within [from, to).") BigDecimal revenueRecovered,
            String revenueRecoveredCurrency) {
    }

    public record RevenueAnalyticsResponse(
            UUID providerId,
            Instant from,
            Instant to,
            BigDecimal totalRevenue,
            String currency,
            BigDecimal averageBookingValue,
            List<DailyAmount> revenueByDay,
            List<ServiceRevenue> revenueByService,
            List<StaffRevenue> revenueByStaff,
            BigDecimal revenueRecovered,
            String revenueRecoveredCurrency) {

        public record DailyAmount(LocalDate date, BigDecimal amount) {
        }

        public record ServiceRevenue(UUID serviceId, String title, BigDecimal amount, long bookingCount) {
        }

        @Schema(description = "employeeId is null for revenue from slots not tied to a specific staff member.")
        public record StaffRevenue(UUID employeeId, BigDecimal amount, long bookingCount) {
        }
    }

    public record BookingAnalyticsResponse(
            UUID providerId,
            Instant from,
            Instant to,
            long totalBookings,
            long completedBookings,
            long upcomingBookings,
            long cancelledBookings,
            long noShowBookings,
            double cancellationRate,
            double noShowRate,
            @Schema(description = "Share of this period's distinct customers who booked more than once in it.")
            double repeatBookingRate,
            List<DailyBookingCount> trend) {

        public record DailyBookingCount(LocalDate date, long total, long completed, long cancelled, long noShow) {
        }
    }

    public record CustomerAnalyticsResponse(
            UUID providerId,
            Instant from,
            Instant to,
            @Schema(description = "Every customer who has ever had a relationship with this provider.") long totalCustomers,
            long activeCustomers,
            @Schema(description = "Customers with more than one completed booking, lifetime.") long returningCustomers,
            @Schema(description = "Customers whose first-ever visit falls within [from, to).") long newCustomers,
            long dueForRebooking,
            long atRiskCustomers,
            long inactiveCustomers,
            Double averageVisitIntervalDays,
            BigDecimal averageCustomerValue,
            String currency,
            List<FavouriteService> favouriteServices,
            List<FavouriteStaff> favouriteStaff) {

        public record FavouriteService(UUID serviceId, String title, long customerCount) {
        }

        public record FavouriteStaff(UUID employeeId, long customerCount) {
        }
    }

    @Schema(description = "One customer behind a CustomerAnalyticsResponse count -- the Action Center's "
            + "rebook-opportunity/retention-risk drill-down.")
    public record CustomerListItem(
            UUID userId,
            String displayName,
            String email,
            RetentionStatus retentionStatus,
            @Schema(description = "Their most recent COMPLETED booking's slot start -- null if none yet.")
            Instant lastVisitAt,
            @Schema(description = "Customer Intelligence's predicted next-visit date, from their own established "
                    + "cadence -- null if none established yet.")
            Instant nextExpectedVisitAt,
            @Schema(description = "Lifetime spend with this provider, from SUCCEEDED payments only.")
            BigDecimal totalSpent,
            String currency,
            String favouriteServiceTitle,
            @Schema(description = "How many of their bookings with this provider were marked NO_SHOW.")
            int noShows) {
    }

    public record ActionCenterResponse(UUID providerId, List<ActionItem> actions) {
    }

    /**
     * Deterministic, rule-based signals only — never a generated
     * recommendation. New rule types extend this enum and add one more
     * branch to {@link BusinessAnalyticsService#actions}; the client owns
     * the copy for each type via its own localization.
     */
    public enum ActionItemType {
        /** Cancelled slots Smart Fill is still actively trying to recover. */
        SMART_FILL_OPPORTUNITY,
        /** Customers whose usual visit interval has just elapsed. */
        REBOOK_OPPORTUNITY,
        /** Customers well past their usual visit interval, drifting but not yet written off. */
        RETENTION_RISK,
        /** A near-term day whose booked/offered slot ratio is below a healthy threshold. */
        LOW_UTILIZATION
    }

    @Schema(description = "count is the number the client interpolates into its localized copy for `type` "
            + "(e.g. \"{count} cancelled slots are currently available\").")
    public record ActionItem(ActionItemType type, long count) {
    }
}
