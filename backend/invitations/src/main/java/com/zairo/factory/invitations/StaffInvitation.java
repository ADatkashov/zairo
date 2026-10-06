package com.zairo.factory.invitations;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "staff_invitation")
public class StaffInvitation {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(nullable = false)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private InvitationKind kind;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private InvitationStatus status;

    @Column(name = "failure_reason")
    private String failureReason;

    @Column(name = "accepted_user_id")
    private UUID acceptedUserId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    protected StaffInvitation() {
    }

    public StaffInvitation(UUID id, UUID providerId, String phone, InvitationKind kind, Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.phone = phone;
        this.kind = kind;
        this.status = InvitationStatus.PENDING;
        this.createdAt = createdAt;
    }

    void accept(UUID userId) {
        this.status = InvitationStatus.ACCEPTED;
        this.acceptedUserId = userId;
        this.resolvedAt = Instant.now();
    }

    void fail(String reason) {
        this.status = InvitationStatus.FAILED;
        this.failureReason = reason == null ? null : reason.substring(0, Math.min(reason.length(), 255));
        this.resolvedAt = Instant.now();
    }

    void cancel() {
        this.status = InvitationStatus.CANCELLED;
        this.resolvedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public String getPhone() {
        return phone;
    }

    public InvitationKind getKind() {
        return kind;
    }

    public InvitationStatus getStatus() {
        return status;
    }

    public String getFailureReason() {
        return failureReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
