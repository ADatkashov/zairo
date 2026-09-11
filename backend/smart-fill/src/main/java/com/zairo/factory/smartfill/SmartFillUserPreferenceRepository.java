package com.zairo.factory.smartfill;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SmartFillUserPreferenceRepository extends JpaRepository<SmartFillUserPreference, UUID> {

    Optional<SmartFillUserPreference> findByUserId(UUID userId);
}
