package com.zairo.factory.search;

import com.zairo.factory.providers.ProviderStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class SearchDtos {

    private SearchDtos() {
    }

    public record ServiceSummary(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "Classic Manicure") String title,
            @Schema(example = "60") int durationMinutes,
            @Schema(example = "25.00") BigDecimal price,
            @Schema(example = "USD") String currency) {
    }

    public record ProviderSearchResult(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "Aigerim Beauty Studio") String name,
            @Schema(example = "beauty") String vertical,
            ProviderStatus status,
            @Schema(description = "True if at least one OPEN slot exists for this provider right now.")
            boolean hasOpenAvailability,
            @Schema(description = "The cheapest active service's price, null if it has none.", example = "25.00")
            BigDecimal minPrice,
            List<ServiceSummary> services,
            @Schema(description = "Null unless both `lat`/`lng` were supplied on the request.", example = "1.8")
            Double distanceKm,
            @Schema(example = "43.238293") Double latitude,
            @Schema(example = "76.945465") Double longitude,
            @Schema(description = "Null if the provider has no reviews yet (absent, not zero).", example = "4.5")
            Double averageRating,
            @Schema(example = "12") Long reviewCount,
            @Schema(description = "The starts_at of the soonest OPEN slot — same source as hasOpenAvailability, "
                    + "null exactly when that's false.", example = "2026-08-28T13:30:00Z")
            Instant nextAvailableSlot,
            @Schema(description = "Null until the provider's owner sets one via PUT /providers/{id}.",
                    example = "http://localhost:8080/api/v1/uploads/a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d.jpg")
            String coverPhotoUrl,
            @Schema(example = "Abay Ave 10, Almaty") String address,
            @Schema(example = "+7 701 000 00 00") String phone,
            String description,
            @Schema(description = "Opening hours by weekday (mon..sun -> HH:mm-HH:mm); empty if not stated.")
            java.util.Map<String, String> workingHours) {
    }

    /** {@code totalCount} is every match, not just what fits in this page — see SearchController's paging params. */
    public record SearchResults(List<ProviderSearchResult> content, long totalCount) {
    }
}
