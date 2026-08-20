package com.zairo.factory.providers;

import java.time.Instant;
import java.util.UUID;

public final class ProviderDtos {

    private ProviderDtos() {
    }

    public record CreateProviderRequest(UUID ownerUserId, String name, String vertical, Double latitude,
            Double longitude) {
        // Convenience constructor for callers that don't set a location —
        // keeps every pre-existing 3-arg call site (mostly tests) compiling
        // without a mechanical find-and-replace across the codebase.
        public CreateProviderRequest(UUID ownerUserId, String name, String vertical) {
            this(ownerUserId, name, vertical, null, null);
        }
    }

    public record UpdateProviderRequest(String name, Double latitude, Double longitude) {
    }

    public record ProviderResponse(UUID id, UUID ownerUserId, String name, String vertical, ProviderStatus status,
            Instant createdAt, Double latitude, Double longitude) {
        static ProviderResponse from(Provider provider) {
            return new ProviderResponse(provider.getId(), provider.getOwnerUserId(), provider.getName(),
                    provider.getVertical(), provider.getStatus(), provider.getCreatedAt(), provider.getLatitude(),
                    provider.getLongitude());
        }
    }
}
