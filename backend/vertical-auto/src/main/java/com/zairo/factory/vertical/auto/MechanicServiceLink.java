package com.zairo.factory.vertical.auto;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/**
 * Which Core {@code Service}s a given {@link Mechanic} can perform. Named
 * {@code MechanicServiceLink} rather than {@code MechanicService} to avoid
 * clashing with Spring's {@code @Service} stereotype — same reasoning as
 * vertical-beauty's {@code MasterServiceLink}.
 */
@Entity
@Table(name = "auto_mechanic_service")
public class MechanicServiceLink {

    @Id
    private UUID id;

    @Column(name = "mechanic_id", nullable = false)
    private UUID mechanicId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    protected MechanicServiceLink() {
    }

    public MechanicServiceLink(UUID id, UUID mechanicId, UUID serviceId) {
        this.id = id;
        this.mechanicId = mechanicId;
        this.serviceId = serviceId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getMechanicId() {
        return mechanicId;
    }

    public UUID getServiceId() {
        return serviceId;
    }
}
