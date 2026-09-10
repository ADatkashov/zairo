package com.zairo.factory.notifications;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.notifications.NotificationDtos.NotificationResponse;
import com.zairo.factory.notifications.NotificationDtos.UnreadCountResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * The in-app notification feed — only the customer-facing subset of events
 * {@link InAppNotificationType} covers. Owner-only: every endpoint requires
 * the caller's own id (from their access token) to match the {@code userId}
 * in the path, same as {@code FavoritesController}.
 */
@RestController
@Tag(name = "Notifications")
public class NotificationsController {

    private final NotificationService notificationService;

    public NotificationsController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @Operation(summary = "List a user's notifications", description = "Newest first. Owner-only: the caller must "
            + "be the exact user named by `userId`.")
    @ApiResponse(responseCode = "200", description = "The user's notifications (empty list if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/notifications")
    public List<NotificationResponse> list(
            @Parameter(description = "The user's id.") @PathVariable UUID userId, HttpServletRequest httpRequest) {
        requireSelf(userId, httpRequest);
        return notificationService.list(userId);
    }

    @Operation(summary = "Count a user's unread notifications", description = "For the Home bell icon's badge. "
            + "Owner-only: the caller must be the exact user named by `userId`.")
    @ApiResponse(responseCode = "200", description = "The unread count")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/notifications/unread-count")
    public UnreadCountResponse unreadCount(
            @Parameter(description = "The user's id.") @PathVariable UUID userId, HttpServletRequest httpRequest) {
        requireSelf(userId, httpRequest);
        return notificationService.unreadCount(userId);
    }

    @Operation(summary = "Mark one notification read", description = "Owner-only: the caller must be the exact "
            + "user named by `userId`, and the notification must be theirs.")
    @ApiResponse(responseCode = "204", description = "Marked read")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/users/{userId}/notifications/{notificationId}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Parameter(description = "The notification's id.") @PathVariable UUID notificationId,
            HttpServletRequest httpRequest) {
        requireSelf(userId, httpRequest);
        notificationService.markRead(userId, notificationId);
    }

    @Operation(summary = "Mark every notification read", description = "Owner-only: the caller must be the exact "
            + "user named by `userId`.")
    @ApiResponse(responseCode = "204", description = "Marked read (a no-op if there were none unread)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/users/{userId}/notifications/read-all")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markAllRead(
            @Parameter(description = "The user's id.") @PathVariable UUID userId, HttpServletRequest httpRequest) {
        requireSelf(userId, httpRequest);
        notificationService.markAllRead(userId);
    }

    private static void requireSelf(UUID userId, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot act on another user's notifications");
        }
    }
}
