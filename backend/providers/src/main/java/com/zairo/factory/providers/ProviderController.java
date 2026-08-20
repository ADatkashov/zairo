package com.zairo.factory.providers;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.ProviderResponse;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderRequest;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class ProviderController {

    private final ProviderRepository providerRepository;

    public ProviderController(ProviderRepository providerRepository) {
        this.providerRepository = providerRepository;
    }

    /** Owner-only: the caller must be authenticated and must be the exact user named as owner — can't create a provider "owned" by someone else. */
    @PostMapping("/api/v1/providers")
    @ResponseStatus(HttpStatus.CREATED)
    public ProviderResponse create(@RequestBody CreateProviderRequest request, HttpServletRequest httpRequest) {
        UUID currentUserId = CurrentUser.requireUserId(httpRequest);
        if (!request.ownerUserId().equals(currentUserId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Cannot create a provider owned by a different user");
        }
        Provider provider = new Provider(UUID.randomUUID(), request.ownerUserId(), request.name(),
                request.vertical(), ProviderStatus.PENDING, Instant.now(), request.latitude(),
                request.longitude());
        return ProviderResponse.from(providerRepository.save(provider));
    }

    @GetMapping("/api/v1/providers")
    public List<ProviderResponse> list() {
        return providerRepository.findAll().stream().map(ProviderResponse::from).toList();
    }

    @GetMapping("/api/v1/providers/{id}")
    public ProviderResponse getById(@PathVariable UUID id) {
        return providerRepository.findById(id).map(ProviderResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + id));
    }

    /** Owner-only. Name/location only — see Provider.update()'s doc comment for what's deliberately not editable. */
    @PutMapping("/api/v1/providers/{id}")
    public ProviderResponse update(@PathVariable UUID id, @RequestBody UpdateProviderRequest request,
            HttpServletRequest httpRequest) {
        Provider provider = providerRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + id));
        UUID currentUserId = CurrentUser.requireUserId(httpRequest);
        if (!provider.getOwnerUserId().equals(currentUserId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this provider: " + id);
        }
        provider.update(request.name(), request.latitude(), request.longitude());
        return ProviderResponse.from(providerRepository.save(provider));
    }

    /** For the Business Admin app: "which salons does this owner manage." */
    @GetMapping("/api/v1/users/{ownerUserId}/providers")
    public List<ProviderResponse> listByOwner(@PathVariable UUID ownerUserId) {
        return providerRepository.findByOwnerUserId(ownerUserId).stream().map(ProviderResponse::from).toList();
    }
}
