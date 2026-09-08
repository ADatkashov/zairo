package com.zairo.factory.providers;

import com.zairo.factory.platformadmin.PlatformAuditLogService;
import com.zairo.factory.providers.ProviderDtos.PlatformSetProviderStatusRequest;
import com.zairo.factory.providers.ProviderDtos.ProviderResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Business moderation from the Control Center — the same action the legacy
 * {@code users.UserRole.ADMIN} path (PATCH /providers/{id}/status) already
 * performs, now also reachable by PLATFORM_ADMIN/PLATFORM_MODERATOR without
 * a second, unrelated login. Every status change is audit-logged through
 * {@link PlatformAuditLogService}, closing the gap called out in
 * docs/PRODUCT_PRODUCTION_ROADMAP.md ("Модерация бизнеса не в audit log").
 */
@Service
public class ProviderAdminService {

    private final ProviderRepository providerRepository;
    private final PlatformAuditLogService auditLogService;

    public ProviderAdminService(ProviderRepository providerRepository, PlatformAuditLogService auditLogService) {
        this.providerRepository = providerRepository;
        this.auditLogService = auditLogService;
    }

    public List<ProviderResponse> list(ProviderStatus status) {
        List<Provider> providers = status == null ? providerRepository.findAll()
                : providerRepository.findByStatus(status);
        return providers.stream().map(ProviderResponse::from).toList();
    }

    @Transactional
    public ProviderResponse setStatus(UUID actorId, String actorEmail, UUID id,
            PlatformSetProviderStatusRequest request) {
        Provider provider = providerRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + id));
        String previous = provider.getStatus().name();
        provider.updateStatus(request.status());
        auditLogService.record(actorId, actorEmail, "PROVIDER_STATUS_CHANGED", "PROVIDER", id, previous,
                request.status().name(), request.reason());
        return ProviderResponse.from(providerRepository.save(provider));
    }
}
