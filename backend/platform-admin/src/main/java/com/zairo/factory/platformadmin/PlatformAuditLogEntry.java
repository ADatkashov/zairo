package com.zairo.factory.platformadmin;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Append-only — no update/delete method exists on purpose, matching
 * {@code subscriptions.SubscriptionCharge}'s "one row per attempt" shape
 * rather than a mutable current-state row. {@code actorEmail} is a
 * denormalized snapshot taken at write time: an audit row should read as
 * "who did this, as it was true then," not follow the actor account if it's
 * later renamed.
 */
@Entity
@Table(name = "platform_audit_log")
public class PlatformAuditLogEntry {

    @Id
    private UUID id;

    @Column(name = "actor_id", nullable = false)
    private UUID actorId;

    @Column(name = "actor_email", nullable = false)
    private String actorEmail;

    @Column(nullable = false)
    private String action;

    @Column(name = "target_type")
    private String targetType;

    @Column(name = "target_id")
    private UUID targetId;

    @Column(name = "previous_value")
    private String previousValue;

    @Column(name = "new_value")
    private String newValue;

    private String reason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected PlatformAuditLogEntry() {
    }

    public PlatformAuditLogEntry(UUID id, UUID actorId, String actorEmail, String action, String targetType,
            UUID targetId, String previousValue, String newValue, String reason, Instant createdAt) {
        this.id = id;
        this.actorId = actorId;
        this.actorEmail = actorEmail;
        this.action = action;
        this.targetType = targetType;
        this.targetId = targetId;
        this.previousValue = previousValue;
        this.newValue = newValue;
        this.reason = reason;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getActorId() {
        return actorId;
    }

    public String getActorEmail() {
        return actorEmail;
    }

    public String getAction() {
        return action;
    }

    public String getTargetType() {
        return targetType;
    }

    public UUID getTargetId() {
        return targetId;
    }

    public String getPreviousValue() {
        return previousValue;
    }

    public String getNewValue() {
        return newValue;
    }

    public String getReason() {
        return reason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
