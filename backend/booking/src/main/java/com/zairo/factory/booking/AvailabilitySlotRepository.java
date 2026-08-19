package com.zairo.factory.booking;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AvailabilitySlotRepository extends JpaRepository<AvailabilitySlot, UUID> {

    List<AvailabilitySlot> findByProviderId(UUID providerId);
}
