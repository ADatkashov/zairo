package com.zairo.factory.providerinsights;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ProviderInsightsDtos {

    private ProviderInsightsDtos() {
    }

    public record CustomerSummary(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @Schema(example = "Aigerim Bekova") String displayName,
            @Schema(example = "aigerim@example.com") String email,
            @Schema(description = "Every booking ever made with this provider, any status.", example = "5")
            int totalBookings,
            @Schema(example = "3") int completedBookings,
            @Schema(description = "Sum of SUCCEEDED payments across this customer's bookings.", example = "90.00")
            BigDecimal totalSpent,
            @Schema(example = "USD") String currency,
            @Schema(description = "The starts_at of their most recent COMPLETED booking's slot — null if none "
                    + "completed yet.")
            Instant lastVisitAt,
            @Schema(description = "The title of their most-booked service — null if they have no bookings.",
                    example = "Haircut")
            String favoriteServiceTitle) {
    }

    public record DashboardMetrics(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(description = "Every booking ever made against this provider, any status.", example = "42")
            long totalBookings,
            @Schema(example = "30") long completedBookings,
            @Schema(example = "6") long cancelledBookings,
            @Schema(description = "cancelledBookings / totalBookings, 0 if there are no bookings yet.", example = "0.14")
            double cancellationRate,
            @Schema(description = "Distinct customers who have ever booked with this provider.", example = "18")
            long totalCustomers,
            @Schema(description = "Value of this provider's COMPLETED bookings, however they were paid (online or at the venue).", example = "2400.00")
            BigDecimal totalRevenue,
            @Schema(description = "totalRevenue divided by the number of COMPLETED bookings — null if there are none yet.",
                    example = "80.00")
            BigDecimal averageCheck,
            @Schema(example = "USD", description = "Null if this provider has no COMPLETED bookings yet.")
            String currency,
            @Schema(description = "This provider's services ranked by booking count, most-booked first, capped at 5.")
            List<TopService> topServices) {

        public record TopService(
                @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
                @Schema(example = "Haircut") String title,
                @Schema(example = "12") long bookingCount) {
        }
    }

    /**
     * What a moderator needs to decide about a business without opening it in another tool: who runs it, how to reach
     * them, and whether it is real (services listed, bookings taken).
     */
    public record PlatformBusinessOverview(
            UUID providerId,
            @Schema(description = "The owner's display name — null if they have not set one.", example = "Aigerim S.")
            String ownerName,
            @Schema(description = "The owner's e-mail — null for a phone-only account.") String ownerEmail,
            @Schema(description = "The owner's phone — null for an e-mail account.") String ownerPhone,
            @Schema(description = "Services the business has listed (active or not).", example = "6") long servicesCount,
            @Schema(example = "42") long totalBookings,
            @Schema(example = "30") long completedBookings) {
    }
}
