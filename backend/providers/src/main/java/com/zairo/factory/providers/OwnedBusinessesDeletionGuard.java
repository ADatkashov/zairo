package com.zairo.factory.providers;

import com.zairo.factory.auth.AccountDeletionGuard;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** A business owner can't delete their account while they still own a business -- it would be left with no owner. */
@Component
class OwnedBusinessesDeletionGuard implements AccountDeletionGuard {

    private final ProviderRepository providerRepository;

    OwnedBusinessesDeletionGuard(ProviderRepository providerRepository) {
        this.providerRepository = providerRepository;
    }

    @Override
    public Optional<String> blockingReason(UUID userId) {
        return providerRepository.countByOwnerUserId(userId) > 0
                ? Optional.of("You own a business. Remove your businesses first, then delete your account.")
                : Optional.empty();
    }
}
