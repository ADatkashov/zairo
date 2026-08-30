package com.zairo.factory.staff;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/**
 * Which Core {@code Service}s a given {@link Staff} member can perform.
 * Named {@code StaffServiceLink} rather than {@code StaffService} to avoid
 * clashing with Spring's {@code @Service} stereotype — same reasoning as
 * vertical-beauty's {@code MasterServiceLink}.
 */
@Entity
@Table(name = "staff_service")
public class StaffServiceLink {

    @Id
    private UUID id;

    @Column(name = "staff_id", nullable = false)
    private UUID staffId;

    @Column(name = "service_id", nullable = false)
    private UUID serviceId;

    protected StaffServiceLink() {
    }

    public StaffServiceLink(UUID id, UUID staffId, UUID serviceId) {
        this.id = id;
        this.staffId = staffId;
        this.serviceId = serviceId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getStaffId() {
        return staffId;
    }

    public UUID getServiceId() {
        return serviceId;
    }
}
