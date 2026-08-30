package com.zairo.factory.catalog;

import com.zairo.factory.catalog.CatalogDtos.BusinessTypeResponse;
import com.zairo.factory.catalog.CatalogDtos.CatalogServiceResponse;
import com.zairo.factory.catalog.CatalogDtos.CategoryResponse;
import com.zairo.factory.catalog.CatalogDtos.CreateBusinessTypeRequest;
import com.zairo.factory.catalog.CatalogDtos.CreateCatalogServiceRequest;
import com.zairo.factory.catalog.CatalogDtos.CreateCategoryRequest;
import com.zairo.factory.catalog.CatalogDtos.CreateSubsphereRequest;
import com.zairo.factory.catalog.CatalogDtos.SetStatusRequest;
import com.zairo.factory.catalog.CatalogDtos.SubsphereResponse;
import com.zairo.factory.catalog.CatalogDtos.UpdateBusinessTypeRequest;
import com.zairo.factory.catalog.CatalogDtos.UpdateCatalogServiceRequest;
import com.zairo.factory.catalog.CatalogDtos.UpdateCategoryRequest;
import com.zairo.factory.catalog.CatalogDtos.UpdateSubsphereRequest;
import com.zairo.factory.platformadmin.PlatformAdminService;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * PLATFORM_ADMIN-only mutation of the master catalog — public reads live in
 * {@link CatalogController}. Reuses the platform-admin module's caller
 * resolution and audit log wholesale; no second admin auth system.
 */
@RestController
@Tag(name = "Platform Admin — Catalog")
public class CatalogAdminController {

    private final CatalogAdminService catalogAdminService;
    private final PlatformAdminService platformAdminService;

    public CatalogAdminController(CatalogAdminService catalogAdminService, PlatformAdminService platformAdminService) {
        this.catalogAdminService = catalogAdminService;
        this.platformAdminService = platformAdminService;
    }

    // ---- Category ----------------------------------------------------

    @Operation(summary = "Create a category")
    @ApiResponse(responseCode = "201", description = "Category created")
    @ApiResponse(responseCode = "409", description = "This code is already registered.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/categories")
    @ResponseStatus(HttpStatus.CREATED)
    public CategoryResponse createCategory(@Valid @RequestBody CreateCategoryRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.createCategory(actorId(httpRequest), actorEmail(httpRequest), request);
    }

    @Operation(summary = "Update a category's names/sort order")
    @ApiResponse(responseCode = "200", description = "Category updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/categories/{id}")
    public CategoryResponse updateCategory(@PathVariable UUID id, @Valid @RequestBody UpdateCategoryRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.updateCategory(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a category")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/categories/{id}/status")
    public CategoryResponse setCategoryStatus(@PathVariable UUID id, @Valid @RequestBody SetStatusRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.setCategoryStatus(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    // ---- BusinessType --------------------------------------------------

    @Operation(summary = "Create a business type")
    @ApiResponse(responseCode = "201", description = "Business type created")
    @ApiResponse(responseCode = "404", description = "The parent category doesn't exist.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "This code is already registered.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/business-types")
    @ResponseStatus(HttpStatus.CREATED)
    public BusinessTypeResponse createBusinessType(@Valid @RequestBody CreateBusinessTypeRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.createBusinessType(actorId(httpRequest), actorEmail(httpRequest), request);
    }

    @Operation(summary = "Update a business type's names/sort order")
    @ApiResponse(responseCode = "200", description = "Business type updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/business-types/{id}")
    public BusinessTypeResponse updateBusinessType(@PathVariable UUID id,
            @Valid @RequestBody UpdateBusinessTypeRequest request, HttpServletRequest httpRequest) {
        return catalogAdminService.updateBusinessType(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a business type")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/business-types/{id}/status")
    public BusinessTypeResponse setBusinessTypeStatus(@PathVariable UUID id,
            @Valid @RequestBody SetStatusRequest request, HttpServletRequest httpRequest) {
        return catalogAdminService.setBusinessTypeStatus(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    // ---- Subsphere -------------------------------------------------------

    @Operation(summary = "Create a subsphere")
    @ApiResponse(responseCode = "201", description = "Subsphere created")
    @ApiResponse(responseCode = "404", description = "The parent business type doesn't exist.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "This code is already registered.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/subspheres")
    @ResponseStatus(HttpStatus.CREATED)
    public SubsphereResponse createSubsphere(@Valid @RequestBody CreateSubsphereRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.createSubsphere(actorId(httpRequest), actorEmail(httpRequest), request);
    }

    @Operation(summary = "Update a subsphere's names/sort order")
    @ApiResponse(responseCode = "200", description = "Subsphere updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/subspheres/{id}")
    public SubsphereResponse updateSubsphere(@PathVariable UUID id, @Valid @RequestBody UpdateSubsphereRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.updateSubsphere(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a subsphere")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/subspheres/{id}/status")
    public SubsphereResponse setSubsphereStatus(@PathVariable UUID id, @Valid @RequestBody SetStatusRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.setSubsphereStatus(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    // ---- CatalogService --------------------------------------------------

    @Operation(summary = "Create a catalog service")
    @ApiResponse(responseCode = "201", description = "Catalog service created")
    @ApiResponse(responseCode = "404", description = "The parent business type doesn't exist.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/services")
    @ResponseStatus(HttpStatus.CREATED)
    public CatalogServiceResponse createCatalogService(@Valid @RequestBody CreateCatalogServiceRequest request,
            HttpServletRequest httpRequest) {
        return catalogAdminService.createCatalogService(actorId(httpRequest), actorEmail(httpRequest), request);
    }

    @Operation(summary = "Update a catalog service's names/sort order")
    @ApiResponse(responseCode = "200", description = "Catalog service updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/services/{id}")
    public CatalogServiceResponse updateCatalogService(@PathVariable UUID id,
            @Valid @RequestBody UpdateCatalogServiceRequest request, HttpServletRequest httpRequest) {
        return catalogAdminService.updateCatalogService(actorId(httpRequest), actorEmail(httpRequest), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a catalog service")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/services/{id}/status")
    public CatalogServiceResponse setCatalogServiceStatus(@PathVariable UUID id,
            @Valid @RequestBody SetStatusRequest request, HttpServletRequest httpRequest) {
        return catalogAdminService.setCatalogServiceStatus(actorId(httpRequest), actorEmail(httpRequest), id,
                request);
    }

    // ---- caller resolution ------------------------------------------

    private UUID actorId(HttpServletRequest httpRequest) {
        UUID adminId = PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        return adminId;
    }

    private String actorEmail(HttpServletRequest httpRequest) {
        return platformAdminService.me(PlatformCurrentAdmin.requireAdminId(httpRequest)).email();
    }
}
