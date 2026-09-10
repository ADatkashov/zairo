package com.zairo.factory.platformadmin;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class PlatformAdminDtos {

    private PlatformAdminDtos() {
    }

    public record LoginRequest(
            @NotBlank @Email @Schema(example = "ops@factory.internal") String email,
            @NotBlank @Schema(example = "Password123") String password) {
    }

    // Same 8-character floor the customer/business side enforces (see
    // auth.AuthDtos.RegisterRequest) — no reason for platform accounts to
    // be held to a lower bar.
    public record CreateAdminRequest(
            @NotBlank @Email @Size(max = 255) @Schema(example = "support@factory.internal") String email,
            @NotBlank @Size(min = 8) @Schema(example = "Password123", minLength = 8) String password,
            @NotBlank @Size(max = 255) @Schema(example = "Aigerim Ops") String displayName,
            @NotNull @Schema(example = "PLATFORM_SUPPORT") PlatformRole role,
            @Schema(description = "Recorded on the audit log entry for this action.", example = "New support hire")
            String reason) {
    }

    public record AdminSummary(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "ops@factory.internal") String email,
            @Schema(example = "Aigerim Ops") String displayName,
            PlatformRole role,
            @Schema(description = "False once deactivated — see POST /platform/admins/{adminId}/deactivate.")
            boolean active,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String avatarUrl) {

        static AdminSummary from(PlatformAdminAccount account) {
            return new AdminSummary(account.getId(), account.getEmail(), account.getDisplayName(),
                    account.getRole(), account.isActive(), account.getAvatarUrl());
        }
    }

    public record DeactivateAdminRequest(
            @Schema(description = "Recorded on the audit log entry for this action.", example = "Left the company")
            String reason) {
    }

    public record UpdateAvatarRequest(
            @Size(max = 2048) @Schema(description = "Upload via POST /uploads first, then pass its returned url "
                    + "here. Null/blank removes the avatar.",
                    example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg")
            String avatarUrl) {
    }

    public record TokenResponse(
            @Schema(description = "Short-lived — send as `Authorization: Bearer <accessToken>` on every "
                    + "/api/v1/platform/** request. No refresh token in this phase: log in again once it expires.")
            String accessToken,
            AdminSummary admin) {
    }

    public record AuditLogEntryResponse(
            UUID id,
            @Schema(example = "ops@factory.internal") String actorEmail,
            @Schema(example = "PLATFORM_ADMIN_CREATED") String action,
            String targetType,
            UUID targetId,
            String previousValue,
            String newValue,
            String reason,
            Instant createdAt) {

        static AuditLogEntryResponse from(PlatformAuditLogEntry entry) {
            return new AuditLogEntryResponse(entry.getId(), entry.getActorEmail(), entry.getAction(),
                    entry.getTargetType(), entry.getTargetId(), entry.getPreviousValue(), entry.getNewValue(),
                    entry.getReason(), entry.getCreatedAt());
        }
    }
}
