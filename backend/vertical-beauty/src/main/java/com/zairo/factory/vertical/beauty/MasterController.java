package com.zairo.factory.vertical.beauty;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.vertical.beauty.MasterDtos.AddPortfolioItemRequest;
import com.zairo.factory.vertical.beauty.MasterDtos.CreateMasterRequest;
import com.zairo.factory.vertical.beauty.MasterDtos.MasterResponse;
import com.zairo.factory.vertical.beauty.MasterDtos.MasterServiceResponse;
import com.zairo.factory.vertical.beauty.MasterDtos.PortfolioItemResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Beauty — Masters")
public class MasterController {

    private final MasterDirectoryService masterDirectoryService;

    public MasterController(MasterDirectoryService masterDirectoryService) {
        this.masterDirectoryService = masterDirectoryService;
    }

    @Operation(summary = "Add a master to a provider", description = "Owner-only. The provider must be in "
            + "the beauty vertical. Created active by default.")
    @ApiResponse(responseCode = "201", description = "Master created")
    @ApiResponse(responseCode = "400", ref = "BadRequest", description = "Validation failed, or the provider "
            + "isn't in the beauty vertical.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/beauty/providers/{providerId}/masters")
    @ResponseStatus(HttpStatus.CREATED)
    public MasterResponse create(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateMasterRequest request, HttpServletRequest httpRequest) {
        Master master = masterDirectoryService.createMaster(providerId, request.displayName(), request.bio(),
                request.photoUrl(), CurrentUser.requireUserId(httpRequest));
        return MasterResponse.from(master);
    }

    @Operation(summary = "List a provider's masters", description = "Active masters by default. Pass "
            + "`includeInactive=true` to also see deactivated ones. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Matching masters")
    @GetMapping("/api/v1/beauty/providers/{providerId}/masters")
    public List<MasterResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Include deactivated masters too.")
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return masterDirectoryService.listMastersByProvider(providerId, includeInactive).stream()
                .map(MasterResponse::from).toList();
    }

    @Operation(summary = "Get a master by id")
    @ApiResponse(responseCode = "200", description = "The master")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/beauty/masters/{masterId}")
    public MasterResponse getById(@Parameter(description = "The master's id.") @PathVariable UUID masterId) {
        return MasterResponse.from(masterDirectoryService.getMaster(masterId));
    }

    @Operation(summary = "Deactivate a master (soft-delete)", description = "Owner-only, idempotent.")
    @ApiResponse(responseCode = "204", description = "Deactivated (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/beauty/masters/{masterId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@Parameter(description = "The master's id.") @PathVariable UUID masterId,
            HttpServletRequest httpRequest) {
        masterDirectoryService.deactivateMaster(masterId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Reactivate a master", description = "Owner-only, idempotent — undoes deactivate().")
    @ApiResponse(responseCode = "200", description = "Master reactivated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/beauty/masters/{masterId}/reactivate")
    public MasterResponse reactivate(@Parameter(description = "The master's id.") @PathVariable UUID masterId,
            HttpServletRequest httpRequest) {
        return MasterResponse.from(
                masterDirectoryService.reactivateMaster(masterId, CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "Add a portfolio photo", description = "Owner-only. Upload the file via POST "
            + "/uploads first, then pass its returned url as `imageUrl` here.")
    @ApiResponse(responseCode = "201", description = "Portfolio item added")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/beauty/masters/{masterId}/portfolio")
    @ResponseStatus(HttpStatus.CREATED)
    public PortfolioItemResponse addPortfolioItem(
            @Parameter(description = "The master's id.") @PathVariable UUID masterId,
            @Valid @RequestBody AddPortfolioItemRequest request, HttpServletRequest httpRequest) {
        return PortfolioItemResponse.from(masterDirectoryService.addPortfolioItem(masterId, request.imageUrl(),
                request.caption(), CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "List a master's portfolio photos", description = "No authentication required.")
    @ApiResponse(responseCode = "200", description = "The master's portfolio (empty list if none)")
    @GetMapping("/api/v1/beauty/masters/{masterId}/portfolio")
    public List<PortfolioItemResponse> listPortfolio(
            @Parameter(description = "The master's id.") @PathVariable UUID masterId) {
        return masterDirectoryService.listPortfolio(masterId).stream().map(PortfolioItemResponse::from).toList();
    }

    @Operation(summary = "Link a service to a master", description = "Owner-only. Marks that this master "
            + "performs the given service — required before a beauty booking can name both together (see "
            + "POST /beauty/bookings).")
    @ApiResponse(responseCode = "204", description = "Linked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The master or the service doesn't "
            + "exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/beauty/masters/{masterId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void linkService(@Parameter(description = "The master's id.") @PathVariable UUID masterId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        masterDirectoryService.linkService(masterId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "Unlink a service from a master", description = "Owner-only.")
    @ApiResponse(responseCode = "204", description = "Unlinked")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/beauty/masters/{masterId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlinkService(@Parameter(description = "The master's id.") @PathVariable UUID masterId,
            @Parameter(description = "The service's id.") @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        masterDirectoryService.unlinkService(masterId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @Operation(summary = "List the services a master performs", description = "No authentication required.")
    @ApiResponse(responseCode = "200", description = "The master's linked services (empty list if none)")
    @GetMapping("/api/v1/beauty/masters/{masterId}/services")
    public List<MasterServiceResponse> listServices(
            @Parameter(description = "The master's id.") @PathVariable UUID masterId) {
        return masterDirectoryService.listServices(masterId).stream().map(MasterServiceResponse::from).toList();
    }
}
