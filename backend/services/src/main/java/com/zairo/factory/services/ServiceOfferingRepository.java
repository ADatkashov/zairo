package com.zairo.factory.services;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ServiceOfferingRepository extends JpaRepository<ServiceOffering, UUID> {

    List<ServiceOffering> findByProviderId(UUID providerId);

    List<ServiceOffering> findByProviderIdAndActiveTrue(UUID providerId);

    List<ServiceOffering> findByTitleContainingIgnoreCaseAndActiveTrue(String title);

    List<ServiceOffering> findByCatalogServiceIdInAndActiveTrue(Collection<UUID> catalogServiceIds);
}
