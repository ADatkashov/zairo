package com.zairo.factory.search;

import com.zairo.factory.providers.ProviderStatus;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public final class SearchDtos {

    private SearchDtos() {
    }

    public record ServiceSummary(UUID id, String title, int durationMinutes, BigDecimal price, String currency) {
    }

    public record ProviderSearchResult(UUID id, String name, String vertical, ProviderStatus status,
            boolean hasOpenAvailability, BigDecimal minPrice, List<ServiceSummary> services, Double distanceKm,
            Double latitude, Double longitude) {
    }
}
