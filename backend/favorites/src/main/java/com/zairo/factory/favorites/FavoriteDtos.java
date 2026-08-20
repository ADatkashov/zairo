package com.zairo.factory.favorites;

import com.zairo.factory.providers.ProviderStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class FavoriteDtos {

    private FavoriteDtos() {
    }

    public record ServiceSummary(UUID id, String title, int durationMinutes, BigDecimal price, String currency) {
    }

    /** Same shape as search's ProviderSearchResult — see build.gradle.kts for why this isn't shared directly. */
    public record FavoriteProviderResponse(UUID id, String name, String vertical, ProviderStatus status,
            boolean hasOpenAvailability, BigDecimal minPrice, List<ServiceSummary> services, Instant favoritedAt) {
    }
}
