package com.zairo.factory.workforce;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * The owner-defined schedule settings of one worker: the zone the hours are in and how long each bookable slot
 * is. The weekly hours themselves are {@link WorkerWorkHours}. The existence of this row is what switches a
 * worker from "uses the business's shared slots" to "has their own generated slots".
 */
@Entity
@Table(name = "worker_schedule")
public class WorkerSchedule {

    @Id
    @Column(name = "worker_id")
    private UUID workerId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "zone_id", nullable = false, length = 64)
    private String zoneId;

    @Column(name = "slot_minutes", nullable = false)
    private int slotMinutes;

    @Column(name = "break_minutes", nullable = false)
    private int breakMinutes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected WorkerSchedule() {
    }

    public WorkerSchedule(UUID workerId, UUID providerId, String zoneId, int slotMinutes, int breakMinutes,
            Instant now) {
        this.workerId = workerId;
        this.providerId = providerId;
        this.zoneId = zoneId;
        this.slotMinutes = slotMinutes;
        this.breakMinutes = breakMinutes;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getWorkerId() {
        return workerId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public String getZoneId() {
        return zoneId;
    }

    public int getSlotMinutes() {
        return slotMinutes;
    }

    public int getBreakMinutes() {
        return breakMinutes;
    }

    void update(String zoneId, int slotMinutes, int breakMinutes, Instant now) {
        this.zoneId = zoneId;
        this.slotMinutes = slotMinutes;
        this.breakMinutes = breakMinutes;
        this.updatedAt = now;
    }
}
