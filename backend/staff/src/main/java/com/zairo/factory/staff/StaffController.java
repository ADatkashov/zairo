package com.zairo.factory.staff;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.staff.StaffDtos.CreateStaffRequest;
import com.zairo.factory.staff.StaffDtos.StaffResponse;
import com.zairo.factory.staff.StaffDtos.StaffServiceResponse;
import com.zairo.factory.staff.StaffDtos.UpdatePhotoRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
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
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Generic staff directory — works for a provider in any category, not just
 * beauty/auto/cleaning. See this module's package-info for why this exists
 * alongside those three vertical-specific staff directories.
 */
@RestController
@Tag(name = "Staff")
public class StaffController {

    private final StaffDirectoryService staffDirectoryService;

    public StaffController(StaffDirectoryService staffDirectoryService) {
        this.staffDirectoryService = staffDirectoryService;
    }

    @Operation(summary = "Add a staff member to a provider", description = "Owner-only. Works for a provider "
            + "in any category — unlike POST /beauty/providers/{id}/masters and its auto/cleaning "
            + "equivalents, this doesn't check the provider's vertical. Created active by default.")
    @ApiResponse(responseCode = "201", description = "Staff member created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "402", description = "The owner's subscription plan doesn't allow another "
            + "staff member on this provider — upgrade to add more.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/staff")
    @ResponseStatus(HttpStatus.CREATED)
    public StaffResponse create(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateStaffRequest request, HttpServletRequest httpRequest) {
        Staff staff = staffDirectoryService.createStaff(providerId, request.displayName(), request.bio(),
                request.photoUrl(), CurrentUser.requireUserId(httpRequest));
        return StaffResponse.from(staff);
    }

    @Operation(summary = "List a provider's staff", description = "Active staff by default. Pass "
            + "`includeInactive=true` to also see deactivated ones. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Matching staff")
    @GetMapping("/api/v1/providers/{providerId}/staff")
    public List<StaffResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Include deactivated staff too.")
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return staffDirectoryService.listStaffByProvider(providerId, includeInactive).stream()
                .map(StaffResponse::from).toList();
    }

    @Operation(summary = "Get a staff member by id")
    @ApiResponse(responseCode = "200", description = "The staff member")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/staff/{staffId}")
    public StaffResponse getById(@Parameter(description = "The staff member's id.") @PathVariable UUID staffId) {
        return StaffResponse.from(staffDirectoryService.getStaff(staffId));
    }

    @Operation(summary = "Deactivate a staff member (soft-delete)", description = "Owner-only, idempotent.")
    @ApiResponse(responseCode = "204", description = "Deactivated (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/staff/{staffId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@Parameter(description = "The staff member's id.") @PathVariable UUID staffId,
            HttpServletRequest httpRequest) {
        staffDirectoryService.deactivateStaff(staffId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Reactivate a staff member", description = "Owner-only, idempotent — undoes deactivate().")
    @ApiResponse(responseCode = "200", description = "Staff member reactivated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/staff/{staffId}/reactivate")
    public StaffResponse reactivate(@Parameter(description = "The staff member's id.") @PathVariable UUID staffId,
            HttpServletRequest httpRequest) {
        return StaffResponse.from(
                staffDirectoryService.reactivateStaff(staffId, CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "Update a staff member's photo", description = "Owner-only. Upload the file via POST "
            + "/uploads first, then pass its returned url as `photoUrl` here. Null/blank removes the photo.")
    @ApiResponse(responseCode = "200", description = "Photo updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/staff/{staffId}/photo")
    public StaffResponse updatePhoto(@Parameter(description = "The staff member's id.") @PathVariable UUID staffId,
            @Valid @RequestBody UpdatePhotoRequest request, HttpServletRequest httpRequest) {
        return StaffResponse.from(staffDirectoryService.updateStaffPhoto(staffId, request.photoUrl(),
                CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "Link a service to a staff member", description = "Owner-only. Marks that this staff "
            + "member performs the given service — required before a staff booking can name both together "
            + "(see POST /staff/bookings).")
    @ApiResponse(responseCode = "204", description = "Linked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The staff member or the service "
            + "doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/staff/{staffId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void linkService(@Parameter(description = "The staff member's id.") @PathVariable UUID staffId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        staffDirectoryService.linkService(staffId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Unlink a service from a staff member", description = "Owner-only.")
    @ApiResponse(responseCode = "204", description = "Unlinked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/staff/{staffId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlinkService(@Parameter(description = "The staff member's id.") @PathVariable UUID staffId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        staffDirectoryService.unlinkService(staffId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "List the services a staff member performs", description = "No authentication required.")
    @ApiResponse(responseCode = "200", description = "The staff member's linked services (empty list if none)")
    @GetMapping("/api/v1/staff/{staffId}/services")
    public List<StaffServiceResponse> listServices(
            @Parameter(description = "The staff member's id.") @PathVariable UUID staffId) {
        return staffDirectoryService.listServices(staffId).stream().map(StaffServiceResponse::from).toList();
    }
}
