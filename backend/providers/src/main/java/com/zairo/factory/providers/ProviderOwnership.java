package com.zairo.factory.providers;

import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

/**
 * Shared "does this user own this provider" check for other modules'
 * write endpoints (services/booking/vertical-beauty/vertical-auto) — one
 * place for the 404-vs-403 logic instead of duplicating it in every
 * module that needs it. No role-based override yet (e.g. a future ADMIN
 * bypass) — the only
 * rule right now is exact ownership; revisit if/when an admin console
 * needs to act on someone else's provider.
 */
@Component
public class ProviderOwnership {

    private final ProviderRepository providerRepository;

    public ProviderOwnership(ProviderRepository providerRepository) {
        this.providerRepository = providerRepository;
    }

    /** 404 if the provider doesn't exist, 403 if it exists but isn't owned by {@code userId}. */
    public void requireOwner(UUID providerId, UUID userId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        if (!provider.getOwnerUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this provider: " + providerId);
        }
    }
}
