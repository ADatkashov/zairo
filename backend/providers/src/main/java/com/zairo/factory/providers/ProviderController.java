package com.zairo.factory.providers;

import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.ProviderResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
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

    @PostMapping("/api/v1/providers")
    @ResponseStatus(HttpStatus.CREATED)
    public ProviderResponse create(@RequestBody CreateProviderRequest request) {
        Provider provider = new Provider(UUID.randomUUID(), request.ownerUserId(), request.name(),
                request.vertical(), ProviderStatus.PENDING, Instant.now());
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
}
