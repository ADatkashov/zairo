package com.zairo.factory.vertical.beauty;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MasterRepository extends JpaRepository<Master, UUID> {

    List<Master> findByProviderId(UUID providerId);

    long countByProviderId(UUID providerId);

    List<Master> findByProviderIdAndActiveTrue(UUID providerId);
}
