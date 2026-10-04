package com.zairo.factory.notifications;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

public interface InAppNotificationRepository extends JpaRepository<InAppNotification, UUID> {

    List<InAppNotification> findByRecipientUserIdOrderByCreatedAtDesc(UUID recipientUserId);

    /** Account deletion. */
    void deleteByRecipientUserId(UUID recipientUserId);

    long countByRecipientUserIdAndReadFalse(UUID recipientUserId);

    Optional<InAppNotification> findByIdAndRecipientUserId(UUID id, UUID recipientUserId);

    @Modifying
    @Transactional
    @Query("update InAppNotification n set n.read = true where n.recipientUserId = :recipientUserId and n.read = false")
    void markAllRead(UUID recipientUserId);
}
