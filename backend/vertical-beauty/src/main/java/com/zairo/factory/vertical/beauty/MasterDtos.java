package com.zairo.factory.vertical.beauty;

import com.zairo.factory.services.ServiceOffering;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class MasterDtos {

    private MasterDtos() {
    }

    public record CreateMasterRequest(String displayName, String bio, String photoUrl) {
    }

    public record MasterResponse(UUID id, UUID providerId, String displayName, String bio, String photoUrl,
            boolean active, Instant createdAt) {
        static MasterResponse from(Master master) {
            return new MasterResponse(master.getId(), master.getProviderId(), master.getDisplayName(),
                    master.getBio(), master.getPhotoUrl(), master.isActive(), master.getCreatedAt());
        }
    }

    public record AddPortfolioItemRequest(String imageUrl, String caption) {
    }

    public record PortfolioItemResponse(UUID id, UUID masterId, String imageUrl, String caption,
            Instant createdAt) {
        static PortfolioItemResponse from(PortfolioItem item) {
            return new PortfolioItemResponse(item.getId(), item.getMasterId(), item.getImageUrl(),
                    item.getCaption(), item.getCreatedAt());
        }
    }

    public record MasterServiceResponse(UUID serviceId, String title, int durationMinutes, BigDecimal price,
            String currency) {
        static MasterServiceResponse from(ServiceOffering service) {
            return new MasterServiceResponse(service.getId(), service.getTitle(), service.getDurationMinutes(),
                    service.getPrice(), service.getCurrency());
        }
    }
}
