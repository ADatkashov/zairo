package com.zairo.factory.payments;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SavedCardPreferenceRepository extends JpaRepository<SavedCardPreference, UUID> {
}
