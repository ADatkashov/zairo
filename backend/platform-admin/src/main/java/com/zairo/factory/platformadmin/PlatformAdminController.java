package com.zairo.factory.platformadmin;

import com.zairo.factory.platformadmin.PlatformAdminDtos.AdminSummary;
import com.zairo.factory.platformadmin.PlatformAdminDtos.AuditLogEntryResponse;
import com.zairo.factory.platformadmin.PlatformAdminDtos.CreateAdminRequest;
import com.zairo.factory.platformadmin.PlatformAdminDtos.LoginRequest;
import com.zairo.factory.platformadmin.PlatformAdminDtos.TokenResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
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
    public AdminSummary me(HttpServletRequest httpRequest) {
        UUID adminId = PlatformCurrentAdmin.requireAdminId(httpRequest);
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
    public AdminSummary createAdmin(@Valid @RequestBody CreateAdminRequest request, HttpServletRequest httpRequest) {
        UUID actorId = PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        String actorEmail = adminService.me(actorId).email();
        return adminService.createAdmin(actorId, actorEmail, request);
    }

    @Operation(summary = "List audit log entries", description = "Every platform-admin action recorded so far, "
            + "newest first. Any authenticated platform role can read this — PLATFORM_SUPPORT included.")
    @ApiResponse(responseCode = "200", description = "A page of audit log entries")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/audit-log")
    public Page<AuditLogEntryResponse> auditLog(Pageable pageable, HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAnyRole(httpRequest);
        return auditLogRepository.findAllByOrderByCreatedAtDesc(pageable).map(AuditLogEntryResponse::from);
    }
}
