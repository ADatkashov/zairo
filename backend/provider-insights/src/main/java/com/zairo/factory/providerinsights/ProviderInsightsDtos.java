package com.zairo.factory.providerinsights;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
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
}
