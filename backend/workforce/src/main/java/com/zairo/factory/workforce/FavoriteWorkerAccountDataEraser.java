package com.zairo.factory.workforce;

import com.zairo.factory.auth.AccountDataEraser;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
class FavoriteWorkerAccountDataEraser implements AccountDataEraser {

    private final FavoriteWorkerRepository repository;

    FavoriteWorkerAccountDataEraser(FavoriteWorkerRepository repository) {
        this.repository = repository;
    }

    @Override
    public void eraseDataOf(UUID userId) {
        repository.deleteByUserId(userId);
    }
}
