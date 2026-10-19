package com.zairo.factory.services;

import com.zairo.factory.providers.ProviderOwnership;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Backs {@link OwnsService}: ownership of a service is ownership of the business it belongs to. */
@Component
public class ServiceAccess {

    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;

    ServiceAccess(ServiceOfferingRepository serviceOfferingRepository, ProviderOwnership providerOwnership) {
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
    }

    /** Always {@code true}; a refusal is the exception (401 / 403). */
    public boolean requireCurrentOwner(UUID serviceId) {
        var service = serviceOfferingRepository.findById(serviceId);
        if (service.isPresent()) {
            return providerOwnership.requireCurrentOwner(service.get().getProviderId());
        }
        return true;
    }
}
