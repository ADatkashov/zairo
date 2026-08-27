package com.zairo.factory.platformadmin;

import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PlatformAuditLogRepository extends JpaRepository<PlatformAuditLogEntry, UUID> {

    /** Newest first, regardless of what sort (if any) the caller's Pageable carries. */
    Page<PlatformAuditLogEntry> findAllByOrderByCreatedAtDesc(Pageable pageable);
}
