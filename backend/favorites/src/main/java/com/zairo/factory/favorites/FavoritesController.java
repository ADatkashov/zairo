package com.zairo.factory.favorites;

import com.zairo.factory.favorites.FavoriteDtos.FavoriteProviderResponse;
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

@RestController
public class FavoritesController {

    private final FavoritesService favoritesService;

    public FavoritesController(FavoritesService favoritesService) {
        this.favoritesService = favoritesService;
    }

    @PostMapping("/api/v1/users/{userId}/favorites/{providerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void addFavorite(@PathVariable UUID userId, @PathVariable UUID providerId) {
        favoritesService.addFavorite(userId, providerId);
    }

    @DeleteMapping("/api/v1/users/{userId}/favorites/{providerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeFavorite(@PathVariable UUID userId, @PathVariable UUID providerId) {
        favoritesService.removeFavorite(userId, providerId);
    }

    @GetMapping("/api/v1/users/{userId}/favorites/{providerId}")
    public void checkFavorited(@PathVariable UUID userId, @PathVariable UUID providerId) {
        if (!favoritesService.isFavorited(userId, providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Not favorited");
        }
    }

    @GetMapping("/api/v1/users/{userId}/favorites")
    public List<FavoriteProviderResponse> listFavorites(@PathVariable UUID userId) {
        return favoritesService.listFavorites(userId);
    }
}
