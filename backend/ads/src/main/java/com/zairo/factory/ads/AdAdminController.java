package com.zairo.factory.ads;

import com.zairo.factory.ads.AdDtos.AdminBannerResponse;
import com.zairo.factory.ads.AdDtos.CreateBannerRequest;
import com.zairo.factory.ads.AdDtos.SetStatusRequest;
import com.zairo.factory.ads.AdDtos.UpdateBannerRequest;
import com.zairo.factory.platformadmin.PlatformAdminService;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Platform-side banner management. Reads: any platform role. Writes:
 * PLATFORM_ADMIN or PLATFORM_MODERATOR — a banner is on every customer's Home
 * screen, so it is moderation work, not an admin-only setting.
 */
@RestController
@RequestMapping("/api/v1/platform/ads")
@Tag(name = "Platform Admin - Ads")
public class AdAdminController {

    private final AdService adService;
    private final PlatformAdminService platformAdminService;

    public AdAdminController(AdService adService, PlatformAdminService platformAdminService) {
        this.adService = adService;
        this.platformAdminService = platformAdminService;
    }

    @Operation(summary = "List every banner, newest first, whatever its status")
    @ApiResponse(responseCode = "200", description = "All banners")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping
    public List<AdminBannerResponse> list(HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requireAnyRole(httpRequest);
        return adService.listAll();
    }

    @Operation(summary = "Create a banner", description = "Starts as DRAFT unless ACTIVE is asked for. "
            + "imageUrl and videoUrl must be https.")
    @ApiResponse(responseCode = "201", description = "Banner created")
    @ApiResponse(responseCode = "400", description = "Invalid fields (non-https URL, end before start, ...)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "PLATFORM_SUPPORT is read-only")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminBannerResponse create(@Valid @RequestBody CreateBannerRequest request,
            HttpServletRequest httpRequest) {
        return adService.create(actorId(httpRequest), actorEmail(httpRequest), request);
    }

    @Operation(summary = "Edit a banner's content and schedule (status moves through /status)")
    @ApiResponse(responseCode = "200", description = "Banner updated")
    @ApiResponse(responseCode = "404", description = "No such banner")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/{id}")
    public AdminBannerResponse update(@PathVariable UUID id, @Valid @RequestBody UpdateBannerRequest request,
            HttpServletRequest httpRequest) {
        return adService.update(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    @Operation(summary = "Approve, pause or reject a banner", description = "Rejecting needs a reason. "
            + "A move the lifecycle does not allow is a 409.")
    @ApiResponse(responseCode = "200", description = "Status changed")
    @ApiResponse(responseCode = "400", description = "Rejection without a reason")
    @ApiResponse(responseCode = "409", description = "Not an allowed move from the current status")
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/{id}/status")
    public AdminBannerResponse setStatus(@PathVariable UUID id, @Valid @RequestBody SetStatusRequest request,
            HttpServletRequest httpRequest) {
        return adService.setStatus(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    @Operation(summary = "Delete a banner for good (pause it instead to keep the record)")
    @ApiResponse(responseCode = "204", description = "Deleted")
    @ApiResponse(responseCode = "404", description = "No such banner")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id, HttpServletRequest httpRequest) {
        adService.delete(actorId(httpRequest), actorEmail(httpRequest), id);
    }

    private UUID actorId(HttpServletRequest httpRequest) {
        UUID adminId = PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requireModerationCapable(httpRequest);
        return adminId;
    }

    private String actorEmail(HttpServletRequest httpRequest) {
        return platformAdminService.me(PlatformCurrentAdmin.requireAdminId(httpRequest)).email();
    }
}
