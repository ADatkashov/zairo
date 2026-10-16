package com.zairo.factory.waitlist;

import com.zairo.factory.auth.AccountDataEraser;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
class WaitlistAccountDataEraser implements AccountDataEraser {

    private final WaitlistRepository repository;

    WaitlistAccountDataEraser(WaitlistRepository repository) {
        this.repository = repository;
    }

    @Override
    public void eraseDataOf(UUID userId) {
        repository.deleteByUserId(userId);
    }
}
