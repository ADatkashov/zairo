package com.zairo.factory.providers;

import java.time.Instant;
import java.util.UUID;

public final class ProviderDtos {

    private ProviderDtos() {
    }

    public record CreateProviderRequest(UUID ownerUserId, String name, String vertical) {
    }

    public record ProviderResponse(UUID id, UUID ownerUserId, String name, String vertical, ProviderStatus status,
            Instant createdAt) {
        static ProviderResponse from(Provider provider) {
            return new ProviderResponse(provider.getId(), provider.getOwnerUserId(), provider.getName(),
                    provider.getVertical(), provider.getStatus(), provider.getCreatedAt());
        }
    }
}
