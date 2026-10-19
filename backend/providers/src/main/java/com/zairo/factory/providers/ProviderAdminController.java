package com.zairo.factory.providers;

import com.zairo.factory.platformadmin.PlatformAdminService;
import com.zairo.factory.platformadmin.AnyPlatformRole;
import com.zairo.factory.platformadmin.PlatformModerationCapable;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import com.zairo.factory.providers.ProviderDtos.PlatformSetProviderStatusRequest;
import com.zairo.factory.providers.ProviderDtos.ProviderResponse;
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
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Business moderation under {@code /api/v1/platform/**} — the Control
 * Center's own reachable path to the same approve/suspend/reinstate action
 * {@code ProviderController.updateStatus} already exposes to the legacy
 * {@code UserRole.ADMIN} login. Read is open to any authenticated platform
 * role (PLATFORM_SUPPORT included); the status mutation needs
 * PLATFORM_ADMIN or PLATFORM_MODERATOR.
 */
@RestController
@Tag(name = "Platform Admin — Businesses")
public class ProviderAdminController {

    private final ProviderAdminService providerAdminService;
    private final PlatformAdminService platformAdminService;

    public ProviderAdminController(ProviderAdminService providerAdminService,
            PlatformAdminService platformAdminService) {
        this.providerAdminService = providerAdminService;
        this.platformAdminService = platformAdminService;
    }

    @Operation(summary = "List businesses for moderation", description = "Every provider regardless of "
            + "moderation status by default; filter with `?status=PENDING` to see only what's awaiting review. "
            + "Any authenticated platform role can read this.")
    @ApiResponse(responseCode = "200", description = "Matching providers")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/businesses")
    @AnyPlatformRole
    public List<ProviderResponse> list(
            @Parameter(description = "Filter to one moderation status. Omit for every provider.")
            @RequestParam(required = false) ProviderStatus status) {
        return providerAdminService.list(status);
    }

    @Operation(summary = "Approve, suspend, or reinstate a business", description = """
            PLATFORM_ADMIN or PLATFORM_MODERATOR only. This is the Control Center's reachable path to the same \
            action the legacy /api/v1/providers/{id}/status endpoint performs — the two write to the same \
            Provider row, so either login can moderate the same business. Recorded on the audit log as \
            PROVIDER_STATUS_CHANGED.""")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN or PLATFORM_MODERATOR.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/businesses/{id}/status")
    @PlatformModerationCapable
    public ProviderResponse setStatus(@PathVariable UUID id, @Valid @RequestBody PlatformSetProviderStatusRequest request) {
        UUID actorId = PlatformCurrentAdmin.requireAdminId();
        String actorEmail = platformAdminService.me(actorId).email();
        return providerAdminService.setStatus(actorId, actorEmail, id, request);
    }
}
