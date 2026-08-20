package com.zairo.factory.vertical.beauty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/**
 * Which Core {@code Service}s a given {@link Master} can perform. Named
 * {@code MasterServiceLink} rather than {@code MasterService} to avoid
 * clashing with Spring's {@code @Service} stereotype — the same reasoning
 * as {@code ServiceOffering} in the {@code services} module.
 */
@Entity
@Table(name = "beauty_master_service")
public class MasterServiceLink {

    @Id
    private UUID id;

    @Column(name = "master_id", nullable = false)
    private UUID masterId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    protected MasterServiceLink() {
    }

    public MasterServiceLink(UUID id, UUID masterId, UUID serviceId) {
        this.id = id;
        this.masterId = masterId;
        this.serviceId = serviceId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getMasterId() {
        return masterId;
    }

    public UUID getServiceId() {
        return serviceId;
    }
}
