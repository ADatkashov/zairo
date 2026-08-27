package com.zairo.factory.search;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BookAgainDtos {

    private BookAgainDtos() {
    }

    public record BookAgainSuggestion(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Aigerim Beauty Studio") String providerName,
            @Schema(example = "beauty") String vertical,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "Classic Manicure") String serviceTitle,
            @Schema(example = "60") int durationMinutes,
            @Schema(example = "25.00") BigDecimal price,
            @Schema(example = "USD") String currency,
            @Schema(description = "The starts_at of the most recent COMPLETED booking's slot for this "
                    + "(provider, service) pair.", example = "2026-08-01T13:30:00Z")
            Instant lastVisitAt) {
    }
}
