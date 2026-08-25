package com.zairo.factory.favorites;

import com.zairo.factory.providers.ProviderStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class FavoriteDtos {

    private FavoriteDtos() {
    }

    public record ServiceSummary(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "Classic Manicure") String title,
            @Schema(example = "60") int durationMinutes,
            @Schema(example = "25.00") BigDecimal price,
            @Schema(example = "USD") String currency) {
    }

    /** Same shape as search's ProviderSearchResult — see build.gradle.kts for why this isn't shared directly. */
    public record FavoriteProviderResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "Aigerim Beauty Studio") String name,
            @Schema(example = "beauty") String vertical,
            ProviderStatus status,
            @Schema(description = "True if at least one OPEN slot exists for this provider right now.")
            boolean hasOpenAvailability,
            @Schema(description = "The cheapest active service's price, null if it has none.", example = "25.00")
            BigDecimal minPrice,
            List<ServiceSummary> services,
            @Schema(description = "When the caller favorited this provider.") Instant favoritedAt,
            @Schema(description = "Null if the provider has no reviews yet (absent, not zero).", example = "4.5")
            Double averageRating,
            @Schema(example = "12") Long reviewCount) {
    }
}
