package com.zairo.factory.notifications;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;
import java.util.UUID;

public final class NotificationDtos {

    private NotificationDtos() {
    }

    public record NotificationResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            InAppNotificationType type,
            @Schema(example = "Booking confirmed") String title,
            @Schema(example = "Your booking is confirmed. We'll see you there!") String body,
            boolean read,
            Instant createdAt) {

        static NotificationResponse from(InAppNotification notification) {
            return new NotificationResponse(notification.getId(), notification.getType(), notification.getTitle(),
                    notification.getBody(), notification.isRead(), notification.getCreatedAt());
        }
    }

    public record UnreadCountResponse(@Schema(example = "3") long count) {
    }
}
