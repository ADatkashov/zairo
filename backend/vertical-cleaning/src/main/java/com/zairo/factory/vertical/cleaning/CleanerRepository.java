package com.zairo.factory.vertical.cleaning;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CleanerRepository extends JpaRepository<Cleaner, UUID> {

    List<Cleaner> findByProviderId(UUID providerId);

    long countByProviderId(UUID providerId);

    boolean existsByProviderIdAndUserId(UUID providerId, UUID userId);

    List<Cleaner> findByProviderIdAndActiveTrue(UUID providerId);
}
