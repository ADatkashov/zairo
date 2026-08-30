package com.zairo.factory.vertical.cleaning;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/**
 * Which Core {@code Service}s a given {@link Cleaner} can perform. Named
 * {@code CleanerServiceLink} rather than {@code CleanerService} to avoid
 * clashing with Spring's {@code @Service} stereotype — same reasoning as
 * vertical-beauty's {@code MasterServiceLink}.
 */
@Entity
@Table(name = "cleaning_cleaner_service")
public class CleanerServiceLink {

    @Id
    private UUID id;

    @Column(name = "cleaner_id", nullable = false)
    private UUID cleanerId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    protected CleanerServiceLink() {
    }

    public CleanerServiceLink(UUID id, UUID cleanerId, UUID serviceId) {
        this.id = id;
        this.cleanerId = cleanerId;
        this.serviceId = serviceId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCleanerId() {
        return cleanerId;
    }

    public UUID getServiceId() {
        return serviceId;
    }
}
