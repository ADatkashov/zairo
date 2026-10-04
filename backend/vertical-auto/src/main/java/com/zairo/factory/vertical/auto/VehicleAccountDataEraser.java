package com.zairo.factory.vertical.auto;

import com.zairo.factory.auth.AccountDataEraser;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
class VehicleAccountDataEraser implements AccountDataEraser {

    private final VehicleRepository repository;

    VehicleAccountDataEraser(VehicleRepository repository) {
        this.repository = repository;
    }

    @Override
    public void eraseDataOf(UUID userId) {
        repository.deleteByOwnerUserId(userId);
    }
}
