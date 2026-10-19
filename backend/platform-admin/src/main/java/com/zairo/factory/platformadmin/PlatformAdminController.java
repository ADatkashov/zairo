package com.zairo.factory.platformadmin;

import com.zairo.factory.platformadmin.PlatformAdminDtos.AdminSummary;
import com.zairo.factory.platformadmin.PlatformAdminDtos.AuditLogEntryResponse;
import com.zairo.factory.platformadmin.PlatformAdminDtos.CreateAdminRequest;
import com.zairo.factory.platformadmin.PlatformAdminDtos.DeactivateAdminRequest;
import com.zairo.factory.platformadmin.PlatformAdminDtos.LoginRequest;
import com.zairo.factory.platformadmin.PlatformAdminDtos.TokenResponse;
import com.zairo.factory.platformadmin.PlatformAdminDtos.UpdateAvatarRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Everything under {@code /api/v1/platform/**} — deliberately its own path
 * prefix, its own token, its own {@link PlatformCurrentAdmin} checks. No
 * endpoint here accepts or recognizes a customer/business access token.
 */
@RestController
@Tag(name = "Platform Admin")
public class PlatformAdminController {

    private final PlatformAdminService adminService;
    private final PlatformAuditLogRepository auditLogRepository;

    public PlatformAdminController(PlatformAdminService adminService, PlatformAuditLogRepository auditLogRepository) {
        this.adminService = adminService;
        this.auditLogRepository = auditLogRepository;
    }

    @Operation(summary = "Platform staff log in", description = "Exchanges email + password for a platform "
            + "access token. Unrelated to /auth/login — a customer or business-owner account cannot log in here, "
            + "and this token cannot be used against any /api/v1/auth or /api/v1/users endpoint.")
    @ApiResponse(responseCode = "200", description = "Authenticated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "Wrong email or password, or the account is deactivated.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/platform/auth/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest request) {
        return adminService.login(request.email(), request.password());
    }

    @Operation(summary = "Get the current platform account")
    @ApiResponse(responseCode = "200", description = "The caller's platform account")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/auth/me")
    public AdminSummary me() {
        UUID adminId = PlatformCurrentAdmin.requireAdminId();
        return adminService.me(adminId);
    }

    @Operation(summary = "Create another platform account", description = """
            PLATFORM_ADMIN-only. There is no self-registration endpoint for platform staff — the very first \
            account is inserted directly in the database; every one after that is created here by an existing \
            PLATFORM_ADMIN. Recorded on the audit log as PLATFORM_ADMIN_CREATED.""")
    @ApiResponse(responseCode = "201", description = "Account created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "This email is already registered.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/admins")
    @ResponseStatus(HttpStatus.CREATED)
    @PlatformAdminOnly
    public AdminSummary createAdmin(@Valid @RequestBody CreateAdminRequest request) {
        UUID actorId = PlatformCurrentAdmin.requireAdminId();
        String actorEmail = adminService.me(actorId).email();
        return adminService.createAdmin(actorId, actorEmail, request);
    }

    @Operation(summary = "Update the current platform account's avatar", description = "Upload the image via "
            + "POST /uploads first, then pass its returned url here. Pass null/blank to remove the avatar.")
    @ApiResponse(responseCode = "200", description = "Avatar updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/auth/me/avatar")
    public AdminSummary updateAvatar(@Valid @RequestBody UpdateAvatarRequest request) {
        UUID adminId = PlatformCurrentAdmin.requireAdminId();
        return adminService.updateAvatar(adminId, request.avatarUrl());
    }

    @Operation(summary = "List every platform staff account", description = "PLATFORM_ADMIN-only. Active and "
            + "deactivated accounts alike — this is the Control Center's staff directory, not a customer-facing "
            + "list.")
    @ApiResponse(responseCode = "200", description = "Every platform account")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/admins")
    @PlatformAdminOnly
    public List<AdminSummary> listAdmins() {
        return adminService.listAdmins();
    }

    @Operation(summary = "Deactivate a platform account", description = "PLATFORM_ADMIN-only, idempotent. Revokes "
            + "the ability to log in immediately; an already-issued access token stays valid until it expires "
            + "(no revocation list in this phase — see TokenResponse's own doc comment on why tokens are "
            + "short-lived). A platform admin cannot deactivate their own account. Recorded on the audit log as "
            + "PLATFORM_ADMIN_DEACTIVATED.")
    @ApiResponse(responseCode = "200", description = "Account deactivated (or already was)")
    @ApiResponse(responseCode = "400", ref = "BadRequest", description = "The caller tried to deactivate their own account.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/admins/{adminId}/deactivate")
    @PlatformAdminOnly
    public AdminSummary deactivateAdmin(@Parameter(description = "The target account's id.") @PathVariable UUID adminId,
            @RequestBody(required = false) DeactivateAdminRequest request) {
        UUID actorId = PlatformCurrentAdmin.requireAdminId();
        String actorEmail = adminService.me(actorId).email();
        String reason = request == null ? null : request.reason();
        return adminService.deactivateAdmin(actorId, actorEmail, adminId, reason);
    }

    @Operation(summary = "Reactivate a platform account", description = "PLATFORM_ADMIN-only, idempotent — undoes "
            + "deactivate(). Recorded on the audit log as PLATFORM_ADMIN_REACTIVATED.")
    @ApiResponse(responseCode = "200", description = "Account reactivated (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/admins/{adminId}/reactivate")
    @PlatformAdminOnly
    public AdminSummary reactivateAdmin(@Parameter(description = "The target account's id.") @PathVariable UUID adminId,
            @RequestBody(required = false) DeactivateAdminRequest request) {
        UUID actorId = PlatformCurrentAdmin.requireAdminId();
        String actorEmail = adminService.me(actorId).email();
        String reason = request == null ? null : request.reason();
        return adminService.reactivateAdmin(actorId, actorEmail, adminId, reason);
    }

    @Operation(summary = "List audit log entries", description = "Every platform-admin action recorded so far, "
            + "newest first. Any authenticated platform role can read this — PLATFORM_SUPPORT included.")
    @ApiResponse(responseCode = "200", description = "A page of audit log entries")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/audit-log")
    @AnyPlatformRole
    public Page<AuditLogEntryResponse> auditLog(Pageable pageable) {
        return auditLogRepository.findAllByOrderByCreatedAtDesc(pageable).map(AuditLogEntryResponse::from);
    }
}
