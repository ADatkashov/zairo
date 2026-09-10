package com.zairo.factory.vertical.auto;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.vertical.auto.MechanicDtos.CreateMechanicRequest;
import com.zairo.factory.vertical.auto.MechanicDtos.MechanicResponse;
import com.zairo.factory.vertical.auto.MechanicDtos.MechanicServiceResponse;
import com.zairo.factory.vertical.auto.MechanicDtos.UpdatePhotoRequest;
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

@RestController
@Tag(name = "Auto — Mechanics")
public class MechanicController {

    private final MechanicDirectoryService mechanicDirectoryService;

    public MechanicController(MechanicDirectoryService mechanicDirectoryService) {
        this.mechanicDirectoryService = mechanicDirectoryService;
    }

    @Operation(summary = "Add a mechanic to a provider", description = "Owner-only. The provider must be in "
            + "the auto vertical. Created active by default.")
    @ApiResponse(responseCode = "201", description = "Mechanic created")
    @ApiResponse(responseCode = "400", ref = "BadRequest", description = "Validation failed, or the provider "
            + "isn't in the auto vertical.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "402", description = "The owner's subscription plan doesn't allow another "
            + "staff member on this provider — upgrade to add more.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auto/providers/{providerId}/mechanics")
    @ResponseStatus(HttpStatus.CREATED)
    public MechanicResponse create(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateMechanicRequest request, HttpServletRequest httpRequest) {
        Mechanic mechanic = mechanicDirectoryService.createMechanic(providerId, request.displayName(),
                request.bio(), request.photoUrl(), CurrentUser.requireUserId(httpRequest));
        return MechanicResponse.from(mechanic);
    }

    @Operation(summary = "List a provider's mechanics", description = "Active mechanics by default. Pass "
            + "`includeInactive=true` to also see deactivated ones. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Matching mechanics")
    @GetMapping("/api/v1/auto/providers/{providerId}/mechanics")
    public List<MechanicResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Include deactivated mechanics too.")
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return mechanicDirectoryService.listMechanicsByProvider(providerId, includeInactive).stream()
                .map(MechanicResponse::from).toList();
    }

    @Operation(summary = "Get a mechanic by id")
    @ApiResponse(responseCode = "200", description = "The mechanic")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/auto/mechanics/{mechanicId}")
    public MechanicResponse getById(@Parameter(description = "The mechanic's id.") @PathVariable UUID mechanicId) {
        return MechanicResponse.from(mechanicDirectoryService.getMechanic(mechanicId));
    }

    @Operation(summary = "Deactivate a mechanic (soft-delete)", description = "Owner-only, idempotent.")
    @ApiResponse(responseCode = "204", description = "Deactivated (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/auto/mechanics/{mechanicId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@Parameter(description = "The mechanic's id.") @PathVariable UUID mechanicId,
            HttpServletRequest httpRequest) {
        mechanicDirectoryService.deactivateMechanic(mechanicId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Reactivate a mechanic", description = "Owner-only, idempotent — undoes deactivate().")
    @ApiResponse(responseCode = "200", description = "Mechanic reactivated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auto/mechanics/{mechanicId}/reactivate")
    public MechanicResponse reactivate(@Parameter(description = "The mechanic's id.") @PathVariable UUID mechanicId,
            HttpServletRequest httpRequest) {
        return MechanicResponse.from(
                mechanicDirectoryService.reactivateMechanic(mechanicId, CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "Update a mechanic's photo", description = "Owner-only. Upload the file via POST "
            + "/uploads first, then pass its returned url as `photoUrl` here. Null/blank removes the photo.")
    @ApiResponse(responseCode = "200", description = "Photo updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/auto/mechanics/{mechanicId}/photo")
    public MechanicResponse updatePhoto(@Parameter(description = "The mechanic's id.") @PathVariable UUID mechanicId,
            @Valid @RequestBody UpdatePhotoRequest request, HttpServletRequest httpRequest) {
        return MechanicResponse.from(mechanicDirectoryService.updateMechanicPhoto(mechanicId, request.photoUrl(),
                CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "Link a service to a mechanic", description = "Owner-only. Marks that this mechanic "
            + "performs the given service — required before an auto booking can name both together (see "
            + "POST /auto/bookings).")
    @ApiResponse(responseCode = "204", description = "Linked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The mechanic or the service doesn't "
            + "exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auto/mechanics/{mechanicId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void linkService(@Parameter(description = "The mechanic's id.") @PathVariable UUID mechanicId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        mechanicDirectoryService.linkService(mechanicId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Unlink a service from a mechanic", description = "Owner-only.")
    @ApiResponse(responseCode = "204", description = "Unlinked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/auto/mechanics/{mechanicId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlinkService(@Parameter(description = "The mechanic's id.") @PathVariable UUID mechanicId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        mechanicDirectoryService.unlinkService(mechanicId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "List the services a mechanic performs", description = "No authentication required.")
    @ApiResponse(responseCode = "200", description = "The mechanic's linked services (empty list if none)")
    @GetMapping("/api/v1/auto/mechanics/{mechanicId}/services")
    public List<MechanicServiceResponse> listServices(
            @Parameter(description = "The mechanic's id.") @PathVariable UUID mechanicId) {
        return mechanicDirectoryService.listServices(mechanicId).stream().map(MechanicServiceResponse::from)
                .toList();
    }
}
