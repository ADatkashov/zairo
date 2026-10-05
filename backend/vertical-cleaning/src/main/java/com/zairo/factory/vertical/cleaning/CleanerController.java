package com.zairo.factory.vertical.cleaning;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.vertical.cleaning.CleanerDtos.CreateCleanerFromUserRequest;
import com.zairo.factory.vertical.cleaning.CleanerDtos.CreateCleanerRequest;
import com.zairo.factory.vertical.cleaning.CleanerDtos.CleanerResponse;
import com.zairo.factory.vertical.cleaning.CleanerDtos.CleanerServiceResponse;
import com.zairo.factory.vertical.cleaning.CleanerDtos.UpdatePhotoRequest;
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
@Tag(name = "Cleaning — Cleaners")
public class CleanerController {

    private final CleanerDirectoryService cleanerDirectoryService;

    public CleanerController(CleanerDirectoryService cleanerDirectoryService) {
        this.cleanerDirectoryService = cleanerDirectoryService;
    }

    @Operation(summary = "Add a cleaner to a provider", description = "Owner-only. The provider must be in "
            + "the cleaning vertical. Created active by default.")
    @ApiResponse(responseCode = "201", description = "Cleaner created")
    @ApiResponse(responseCode = "400", ref = "BadRequest", description = "Validation failed, or the provider "
            + "isn't in the cleaning vertical.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "402", description = "The owner's subscription plan doesn't allow another "
            + "staff member on this provider — upgrade to add more.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/cleaning/providers/{providerId}/cleaners")
    @ResponseStatus(HttpStatus.CREATED)
    public CleanerResponse create(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateCleanerRequest request, HttpServletRequest httpRequest) {
        Cleaner cleaner = cleanerDirectoryService.createCleaner(providerId, request.displayName(), request.bio(),
                request.photoUrl(), CurrentUser.requireUserId(httpRequest));
        return CleanerResponse.from(cleaner);
    }

    @Operation(summary = "Add an existing user as a cleaner", description = "Owner-only. The cleaner's name and photo "
            + "come from the user's profile (find the user with GET /users/lookup). A user can be a cleaner at a "
            + "provider once.")
    @ApiResponse(responseCode = "201", description = "Cleaner created")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "402", description = "The plan's staff limit is reached.")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider or the user doesn't exist.")
    @ApiResponse(responseCode = "409", description = "This user is already a cleaner at this provider.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/cleaning/providers/{providerId}/cleaners/from-user")
    @ResponseStatus(HttpStatus.CREATED)
    public CleanerResponse createFromUser(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateCleanerFromUserRequest request, HttpServletRequest httpRequest) {
        return CleanerResponse.from(cleanerDirectoryService.createCleanerFromUser(providerId, request.userId(),
                CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "List a provider's cleaners", description = "Active cleaners by default. Pass "
            + "`includeInactive=true` to also see deactivated ones. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Matching cleaners")
    @GetMapping("/api/v1/cleaning/providers/{providerId}/cleaners")
    public List<CleanerResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Include deactivated cleaners too.")
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return cleanerDirectoryService.listCleanersByProvider(providerId, includeInactive).stream()
                .map(CleanerResponse::from).toList();
    }

    @Operation(summary = "Get a cleaner by id")
    @ApiResponse(responseCode = "200", description = "The cleaner")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/cleaning/cleaners/{cleanerId}")
    public CleanerResponse getById(@Parameter(description = "The cleaner's id.") @PathVariable UUID cleanerId) {
        return CleanerResponse.from(cleanerDirectoryService.getCleaner(cleanerId));
    }

    @Operation(summary = "Deactivate a cleaner (soft-delete)", description = "Owner-only, idempotent.")
    @ApiResponse(responseCode = "204", description = "Deactivated (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/cleaning/cleaners/{cleanerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@Parameter(description = "The cleaner's id.") @PathVariable UUID cleanerId,
            HttpServletRequest httpRequest) {
        cleanerDirectoryService.deactivateCleaner(cleanerId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Reactivate a cleaner", description = "Owner-only, idempotent — undoes deactivate().")
    @ApiResponse(responseCode = "200", description = "Cleaner reactivated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/cleaning/cleaners/{cleanerId}/reactivate")
    public CleanerResponse reactivate(@Parameter(description = "The cleaner's id.") @PathVariable UUID cleanerId,
            HttpServletRequest httpRequest) {
        return CleanerResponse.from(
                cleanerDirectoryService.reactivateCleaner(cleanerId, CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "Update a cleaner's photo", description = "Owner-only. Upload the file via POST "
            + "/uploads first, then pass its returned url as `photoUrl` here. Null/blank removes the photo.")
    @ApiResponse(responseCode = "200", description = "Photo updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/cleaning/cleaners/{cleanerId}/photo")
    public CleanerResponse updatePhoto(@Parameter(description = "The cleaner's id.") @PathVariable UUID cleanerId,
            @Valid @RequestBody UpdatePhotoRequest request, HttpServletRequest httpRequest) {
        return CleanerResponse.from(cleanerDirectoryService.updateCleanerPhoto(cleanerId, request.photoUrl(),
                CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "Link a service to a cleaner", description = "Owner-only. Marks that this cleaner "
            + "performs the given service — required before a cleaning booking can name both together (see "
            + "POST /cleaning/bookings).")
    @ApiResponse(responseCode = "204", description = "Linked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The cleaner or the service doesn't "
            + "exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/cleaning/cleaners/{cleanerId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void linkService(@Parameter(description = "The cleaner's id.") @PathVariable UUID cleanerId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        cleanerDirectoryService.linkService(cleanerId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Unlink a service from a cleaner", description = "Owner-only.")
    @ApiResponse(responseCode = "204", description = "Unlinked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/cleaning/cleaners/{cleanerId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlinkService(@Parameter(description = "The cleaner's id.") @PathVariable UUID cleanerId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        cleanerDirectoryService.unlinkService(cleanerId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "List the services a cleaner performs", description = "No authentication required.")
    @ApiResponse(responseCode = "200", description = "The cleaner's linked services (empty list if none)")
    @GetMapping("/api/v1/cleaning/cleaners/{cleanerId}/services")
    public List<CleanerServiceResponse> listServices(
            @Parameter(description = "The cleaner's id.") @PathVariable UUID cleanerId) {
        return cleanerDirectoryService.listServices(cleanerId).stream().map(CleanerServiceResponse::from)
                .toList();
    }
}
