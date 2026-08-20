package com.zairo.factory.services;

import java.math.BigDecimal;
import java.util.UUID;

public final class ServiceOfferingDtos {

    private ServiceOfferingDtos() {
    }

    public record CreateServiceRequest(String title, int durationMinutes, BigDecimal price, String currency) {
    }

    public record UpdateServiceRequest(String title, int durationMinutes, BigDecimal price, String currency) {
    }

    public record ServiceResponse(UUID id, UUID providerId, String title, int durationMinutes, BigDecimal price,
            String currency, boolean active) {
        static ServiceResponse from(ServiceOffering service) {
            return new ServiceResponse(service.getId(), service.getProviderId(), service.getTitle(),
                    service.getDurationMinutes(), service.getPrice(), service.getCurrency(), service.isActive());
        }
    }
}
