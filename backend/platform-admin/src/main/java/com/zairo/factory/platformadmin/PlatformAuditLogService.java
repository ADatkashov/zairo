package com.zairo.factory.platformadmin;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * The one place a platform-admin mutation gets recorded. Every future
 * endpoint that changes platform-wide state (this phase: creating another
 * platform admin; later phases: suspending a business, changing a
 * subscription, ...) should call this instead of writing its own log row —
 * one shape for "who / when / what / before / after" across the whole
 * Control Center.
 */
@Service
public class PlatformAuditLogService {

    private final PlatformAuditLogRepository repository;

    public PlatformAuditLogService(PlatformAuditLogRepository repository) {
        this.repository = repository;
    }

    public void record(UUID actorId, String actorEmail, String action, String targetType, UUID targetId,
            String previousValue, String newValue, String reason) {
        repository.save(new PlatformAuditLogEntry(UUID.randomUUID(), actorId, actorEmail, action, targetType,
                targetId, previousValue, newValue, reason, Instant.now()));
    }
}
