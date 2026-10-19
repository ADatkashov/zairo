package com.zairo.factory.favorites;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.favorites.FavoriteDtos.FavoriteProviderResponse;
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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Owner-only: every endpoint here requires the caller's own id (from their
 * access token) to match the {@code userId} in the path — a user can only
 * manage their own favorites, never someone else's.
 */
@RestController
@Tag(name = "Favorites")
public class FavoritesController {

    private final FavoritesService favoritesService;

    public FavoritesController(FavoritesService favoritesService) {
        this.favoritesService = favoritesService;
    }

    @Operation(summary = "Favorite a provider", description = "Idempotent — favoriting an already-favorited "
            + "provider again is a no-op, still 204. Owner-only: the caller must be the exact user named by "
            + "`userId`.")
    @ApiResponse(responseCode = "204", description = "Favorited (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/users/{userId}/favorites/{providerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void addFavorite(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        requireSelf(userId);
        favoritesService.addFavorite(userId, providerId);
    }

    @Operation(summary = "Unfavorite a provider", description = "Idempotent — removing a favorite that isn't "
            + "there is a no-op, still 204. Owner-only: the caller must be the exact user named by `userId`.")
    @ApiResponse(responseCode = "204", description = "Removed (or already wasn't favorited)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/users/{userId}/favorites/{providerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeFavorite(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        requireSelf(userId);
        favoritesService.removeFavorite(userId, providerId);
    }

    @Operation(summary = "Check whether a provider is favorited", description = "An existence check, not a "
            + "boolean body — 200 with an empty body means favorited, 404 means not. Useful for a quick "
            + "HEAD-style check without pulling the full favorites list. Owner-only: the caller must be the "
            + "exact user named by `userId`.")
    @ApiResponse(responseCode = "200", description = "Favorited")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "Not favorited.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/favorites/{providerId}")
    public void checkFavorited(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        requireSelf(userId);
        if (!favoritesService.isFavorited(userId, providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Not favorited");
        }
    }

    @Operation(summary = "List a user's favorited providers", description = "Full provider cards (rating, "
            + "cheapest price, availability), not just ids — the same shape Search returns. Owner-only: the "
            + "caller must be the exact user named by `userId`.")
    @ApiResponse(responseCode = "200", description = "The user's favorites (empty list if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/favorites")
    public List<FavoriteProviderResponse> listFavorites(
            @Parameter(description = "The user's id.") @PathVariable UUID userId) {
        requireSelf(userId);
        return favoritesService.listFavorites(userId);
    }

    private static void requireSelf(UUID userId) {
        UUID callerId = CurrentUser.requireUserId();
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot act on another user's favorites");
        }
    }
}
