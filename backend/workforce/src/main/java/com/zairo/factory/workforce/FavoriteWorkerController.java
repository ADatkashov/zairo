package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.workforce.WorkerDirectoryDtos.FavoriteWorkerResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/** Owner-only: the caller's id must match {@code userId} — a customer manages only their own "my masters". */
@RestController
@Tag(name = "Workforce — favorite masters")
public class FavoriteWorkerController {

    private final FavoriteWorkerService service;

    public FavoriteWorkerController(FavoriteWorkerService service) {
        this.service = service;
    }

    @Operation(summary = "Add a person to my masters", description = "Idempotent. 404 when the person is not "
            + "publicly listed. Owner-only.")
    @ApiResponse(responseCode = "204", description = "Added (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/users/{userId}/favorite-workers/{workerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void add(@PathVariable UUID userId, @PathVariable UUID workerId, HttpServletRequest request) {
        requireSelf(userId, request);
        service.add(userId, workerId);
    }

    @Operation(summary = "Remove a person from my masters", description = "Idempotent. Owner-only.")
    @ApiResponse(responseCode = "204", description = "Removed (or wasn't there)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/users/{userId}/favorite-workers/{workerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@PathVariable UUID userId, @PathVariable UUID workerId, HttpServletRequest request) {
        requireSelf(userId, request);
        service.remove(userId, workerId);
    }

    @Operation(summary = "Is this person on my masters?", description = "200 with an empty body when yes, 404 "
            + "when not. Owner-only.")
    @ApiResponse(responseCode = "200", description = "On the list")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "Not on the list.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/favorite-workers/{workerId}")
    public void check(@PathVariable UUID userId, @PathVariable UUID workerId, HttpServletRequest request) {
        requireSelf(userId, request);
        if (!service.isFavorited(userId, workerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Not on the list");
        }
    }

    @Operation(summary = "My masters", description = "Newest first, with each person's rating. People who left, "
            + "were deactivated or whose business is no longer listed are left out. Owner-only.")
    @ApiResponse(responseCode = "200", description = "The list (empty when none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/favorite-workers")
    public List<FavoriteWorkerResponse> list(@PathVariable UUID userId, HttpServletRequest request) {
        requireSelf(userId, request);
        return service.list(userId);
    }

    private static void requireSelf(UUID userId, HttpServletRequest request) {
        if (!CurrentUser.requireUserId(request).equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot act on another user's masters");
        }
    }
}
