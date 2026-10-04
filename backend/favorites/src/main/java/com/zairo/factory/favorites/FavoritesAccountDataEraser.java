package com.zairo.factory.favorites;

import com.zairo.factory.auth.AccountDataEraser;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
class FavoritesAccountDataEraser implements AccountDataEraser {

    private final FavoriteRepository repository;

    FavoritesAccountDataEraser(FavoriteRepository repository) {
        this.repository = repository;
    }

    @Override
    public void eraseDataOf(UUID userId) {
        repository.deleteByUserId(userId);
    }
}
