package com.zairo.factory.payments;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentSettingsRepository extends JpaRepository<PaymentSettings, UUID> {
    Optional<PaymentSettings> findByProviderId(UUID providerId);
}
