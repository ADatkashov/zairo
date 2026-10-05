package com.zairo.factory.staff;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StaffRepository extends JpaRepository<Staff, UUID> {

    List<Staff> findByProviderId(UUID providerId);

    long countByProviderId(UUID providerId);

    boolean existsByProviderIdAndUserId(UUID providerId, UUID userId);

    List<Staff> findByProviderIdAndActiveTrue(UUID providerId);
}
