package com.zairo.factory.waitlist;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.waitlist.WaitlistDtos.JoinWaitlistRequest;
import com.zairo.factory.waitlist.WaitlistDtos.WaitlistEntryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/** Owner-only: the caller's own id (from their token) must match the {@code userId} in the path. */
@RestController
@Tag(name = "Waitlist")
public class WaitlistController {

    private final WaitlistService waitlistService;

    public WaitlistController(WaitlistService waitlistService) {
        this.waitlistService = waitlistService;
    }

    @Operation(summary = "Ask to be told when a time frees up", description = "Idempotent — joining again only "
            + "changes the wanted window. The body is optional: without it any time will do. The customer is "
            + "notified once, when a matching time opens, and is then taken off the list.")
    @ApiResponse(responseCode = "204", description = "On the waitlist")
    @ApiResponse(responseCode = "400", description = "The window is empty or already over")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "No such provider.")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/users/{userId}/waitlist/{providerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void join(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @RequestBody(required = false) JoinWaitlistRequest request) {
        requireSelf(userId);
        waitlistService.join(userId, providerId, request == null ? null : request.from(),
                request == null ? null : request.to());
    }

    @Operation(summary = "Leave a waitlist", description = "Idempotent — leaving a list the user is not on is a "
            + "no-op, still 204.")
    @ApiResponse(responseCode = "204", description = "Not on the waitlist (any more)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/users/{userId}/waitlist/{providerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        requireSelf(userId);
        waitlistService.leave(userId, providerId);
    }

    @Operation(summary = "List the businesses a user is waiting for", description = "Active entries only (a window "
            + "that has passed is hidden), newest first.")
    @ApiResponse(responseCode = "200", description = "The user's waitlist (empty list if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/waitlist")
    public List<WaitlistEntryResponse> list(@Parameter(description = "The user's id.") @PathVariable UUID userId) {
        requireSelf(userId);
        return waitlistService.list(userId);
    }

    private static void requireSelf(UUID userId) {
        UUID callerId = CurrentUser.requireUserId();
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot act on another user's waitlist");
        }
    }
}
