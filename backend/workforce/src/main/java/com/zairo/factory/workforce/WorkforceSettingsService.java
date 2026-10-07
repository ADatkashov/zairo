package com.zairo.factory.workforce;

import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.workforce.WorkerScheduleDtos.UpdateWorkforceSettingsRequest;
import com.zairo.factory.workforce.WorkerScheduleDtos.WorkforceSettingsResponse;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Per-business worker rules the owner controls (default: customers may choose a worker, no per-worker prices). */
@Service
public class WorkforceSettingsService {

    private final ProviderOwnership providerOwnership;
    private final ProviderWorkforceSettingsRepository repository;

    public WorkforceSettingsService(ProviderOwnership providerOwnership,
            ProviderWorkforceSettingsRepository repository) {
        this.providerOwnership = providerOwnership;
        this.repository = repository;
    }

    /** Public read — the booking screen needs to know whether to offer a choice of worker. */
    @Transactional(readOnly = true)
    public WorkforceSettingsResponse get(UUID providerId) {
        return repository.findById(providerId)
                .map(s -> new WorkforceSettingsResponse(s.isAllowWorkerChoice(), s.isWorkerPricingEnabled()))
                .orElse(new WorkforceSettingsResponse(true, false));
    }

    public boolean allowsWorkerChoice(UUID providerId) {
        return get(providerId).allowWorkerChoice();
    }

    @Transactional
    public WorkforceSettingsResponse update(UUID providerId, UUID ownerId, UpdateWorkforceSettingsRequest request) {
        providerOwnership.requireOwner(providerId, ownerId);
        Instant now = Instant.now();
        ProviderWorkforceSettings settings = repository.findById(providerId).orElse(null);
        if (settings == null) {
            repository.save(new ProviderWorkforceSettings(providerId, request.allowWorkerChoice(),
                    request.workerPricingEnabled(), now));
        } else {
            settings.update(request.allowWorkerChoice(), request.workerPricingEnabled(), now);
            repository.save(settings);
        }
        return get(providerId);
    }
}
