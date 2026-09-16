package com.zairo.factory.automation;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AutomationSettingsRepository extends JpaRepository<AutomationSettings, UUID> {

    Optional<AutomationSettings> findByProviderId(UUID providerId);
}
