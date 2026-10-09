package com.zairo.factory.workforce;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProviderWorkforceSettingsRepository extends JpaRepository<ProviderWorkforceSettings, UUID> {
}
