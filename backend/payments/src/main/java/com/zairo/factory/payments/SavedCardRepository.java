package com.zairo.factory.payments;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SavedCardRepository extends JpaRepository<SavedCard, UUID> {

    List<SavedCard> findByUserIdOrderByCreatedAtDesc(UUID userId);

    Optional<SavedCard> findByIdAndUserId(UUID id, UUID userId);

    Optional<SavedCard> findByUserIdAndRecurringProfileId(UUID userId, String recurringProfileId);
}
