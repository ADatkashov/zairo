package com.zairo.factory.notifications;

import com.zairo.factory.auth.AccountDataEraser;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
class NotificationsAccountDataEraser implements AccountDataEraser {

    private final InAppNotificationRepository repository;

    NotificationsAccountDataEraser(InAppNotificationRepository repository) {
        this.repository = repository;
    }

    @Override
    public void eraseDataOf(UUID userId) {
        repository.deleteByRecipientUserId(userId);
    }
}
