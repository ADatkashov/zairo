package com.zairo.factory.payments;

import com.zairo.factory.payments.CommissionDtos.CommissionSettingsResponse;
import com.zairo.factory.payments.CommissionDtos.SetCommissionRequest;
import com.zairo.factory.platformadmin.PlatformAdminService;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * The marketplace commission, fully configurable by PLATFORM_ADMIN: one
 * platform-wide default (0% until changed) plus an optional override per
 * catalog category. Any platform role may read; only PLATFORM_ADMIN may
 * change, and every change is audit-logged. A change applies to payments
 * that succeed afterwards — existing allocations keep the rate they were
 * created with.
 */
@RestController
@Tag(name = "Platform Admin — Commission")
public class CommissionAdminController {

    private final CommissionRateService commissionRateService;
    private final PlatformAdminService platformAdminService;

    public CommissionAdminController(CommissionRateService commissionRateService,
            PlatformAdminService platformAdminService) {
        this.commissionRateService = commissionRateService;
        this.platformAdminService = platformAdminService;
    }

    @Operation(summary = "Commission settings", description = "The platform-wide default and, for every "
            + "category, its override (if any) and the rate actually in effect. Percent values.")
    @ApiResponse(responseCode = "200", description = "Current settings")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/commission")
    public CommissionSettingsResponse settings(HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAnyRole(httpRequest);
        return commissionRateService.settings();
    }

    @Operation(summary = "Set the platform-wide default commission", description = "Applies to every category "
            + "without its own override. 0 = no commission.")
    @ApiResponse(responseCode = "200", description = "Updated settings")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/platform/commission/default")
    public CommissionSettingsResponse setDefault(@Valid @RequestBody SetCommissionRequest request,
            HttpServletRequest httpRequest) {
        UUID actorId = actorId(httpRequest);
        return commissionRateService.setDefault(actorId, actorEmail(actorId), request.ratePercent());
    }

    @Operation(summary = "Set a category's own commission", description = "Overrides the default for every "
            + "business whose type belongs to this category.")
    @ApiResponse(responseCode = "200", description = "Updated settings")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/platform/commission/categories/{categoryId}")
    public CommissionSettingsResponse setCategory(@PathVariable UUID categoryId,
            @Valid @RequestBody SetCommissionRequest request, HttpServletRequest httpRequest) {
        UUID actorId = actorId(httpRequest);
        return commissionRateService.setCategory(actorId, actorEmail(actorId), categoryId, request.ratePercent());
    }

    @Operation(summary = "Remove a category's override", description = "The category follows the platform "
            + "default again.")
    @ApiResponse(responseCode = "200", description = "Updated settings")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/platform/commission/categories/{categoryId}")
    public CommissionSettingsResponse clearCategory(@PathVariable UUID categoryId, HttpServletRequest httpRequest) {
        UUID actorId = actorId(httpRequest);
        return commissionRateService.clearCategory(actorId, actorEmail(actorId), categoryId);
    }

    private UUID actorId(HttpServletRequest httpRequest) {
        UUID adminId = PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        return adminId;
    }

    private String actorEmail(UUID adminId) {
        return platformAdminService.me(adminId).email();
    }
}
