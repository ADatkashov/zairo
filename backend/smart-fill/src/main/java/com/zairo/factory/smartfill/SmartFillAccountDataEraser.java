package com.zairo.factory.smartfill;

import com.zairo.factory.auth.AccountDataEraser;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
class SmartFillAccountDataEraser implements AccountDataEraser {

    private final SmartFillUserPreferenceRepository repository;

    SmartFillAccountDataEraser(SmartFillUserPreferenceRepository repository) {
        this.repository = repository;
    }

    @Override
    public void eraseDataOf(UUID userId) {
        repository.findById(userId).ifPresent(repository::delete);
    }
}
