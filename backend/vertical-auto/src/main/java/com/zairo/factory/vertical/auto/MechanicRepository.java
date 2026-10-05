package com.zairo.factory.vertical.auto;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MechanicRepository extends JpaRepository<Mechanic, UUID> {

    List<Mechanic> findByProviderId(UUID providerId);

    long countByProviderId(UUID providerId);

    boolean existsByProviderIdAndUserId(UUID providerId, UUID userId);

    List<Mechanic> findByProviderIdAndActiveTrue(UUID providerId);
}
