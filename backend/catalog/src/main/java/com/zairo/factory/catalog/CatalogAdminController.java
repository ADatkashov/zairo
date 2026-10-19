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
import com.zairo.factory.platformadmin.PlatformAdminOnly;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
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

    @Operation(summary = "List every category, any status", description = "Unlike GET /api/v1/categories "
            + "(ACTIVE-only, unauthenticated), this includes INACTIVE/ARCHIVED — the taxonomy management screen's "
            + "own list, so deactivating a category doesn't make it disappear from the screen that can reactivate "
            + "it. Any authenticated platform role may read this, same as the audit log.")
    @ApiResponse(responseCode = "200", description = "Every category")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/categories")
    public List<CategoryResponse> listAllCategories() {
        PlatformCurrentAdmin.requireAdminId();
        return catalogAdminService.listAllCategories();
    }

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
    @PlatformAdminOnly
    public CategoryResponse createCategory(@Valid @RequestBody CreateCategoryRequest request) {
        return catalogAdminService.createCategory(actorId(), actorEmail(), request);
    }

    @Operation(summary = "Update a category's names/sort order")
    @ApiResponse(responseCode = "200", description = "Category updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/categories/{id}")
    @PlatformAdminOnly
    public CategoryResponse updateCategory(@PathVariable UUID id, @Valid @RequestBody UpdateCategoryRequest request) {
        return catalogAdminService.updateCategory(actorId(), actorEmail(), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a category")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/categories/{id}/status")
    @PlatformAdminOnly
    public CategoryResponse setCategoryStatus(@PathVariable UUID id, @Valid @RequestBody SetStatusRequest request) {
        return catalogAdminService.setCategoryStatus(actorId(), actorEmail(), id, request);
    }

    // ---- BusinessType --------------------------------------------------

    @Operation(summary = "List a category's business types, any status", description = "The admin-only "
            + "counterpart of GET /api/v1/categories/{id}/business-types — see listAllCategories.")
    @ApiResponse(responseCode = "200", description = "Every business type under this category")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", description = "The category doesn't exist.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/categories/{id}/business-types")
    public List<BusinessTypeResponse> listAllBusinessTypes(@PathVariable UUID id) {
        PlatformCurrentAdmin.requireAdminId();
        return catalogAdminService.listAllBusinessTypes(id);
    }

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
    @PlatformAdminOnly
    public BusinessTypeResponse createBusinessType(@Valid @RequestBody CreateBusinessTypeRequest request) {
        return catalogAdminService.createBusinessType(actorId(), actorEmail(), request);
    }

    @Operation(summary = "Update a business type's names/sort order")
    @ApiResponse(responseCode = "200", description = "Business type updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/business-types/{id}")
    @PlatformAdminOnly
    public BusinessTypeResponse updateBusinessType(@PathVariable UUID id,
            @Valid @RequestBody UpdateBusinessTypeRequest request) {
        return catalogAdminService.updateBusinessType(actorId(), actorEmail(), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a business type")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/business-types/{id}/status")
    @PlatformAdminOnly
    public BusinessTypeResponse setBusinessTypeStatus(@PathVariable UUID id,
            @Valid @RequestBody SetStatusRequest request) {
        return catalogAdminService.setBusinessTypeStatus(actorId(), actorEmail(), id, request);
    }

    // ---- Subsphere -------------------------------------------------------

    @Operation(summary = "List a business type's subspheres, any status", description = "The admin-only "
            + "counterpart of GET /api/v1/business-types/{id}/subspheres — see listAllCategories.")
    @ApiResponse(responseCode = "200", description = "Every subsphere under this business type")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", description = "The business type doesn't exist.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/business-types/{id}/subspheres")
    public List<SubsphereResponse> listAllSubspheres(@PathVariable UUID id) {
        PlatformCurrentAdmin.requireAdminId();
        return catalogAdminService.listAllSubspheres(id);
    }

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
    @PlatformAdminOnly
    public SubsphereResponse createSubsphere(@Valid @RequestBody CreateSubsphereRequest request) {
        return catalogAdminService.createSubsphere(actorId(), actorEmail(), request);
    }

    @Operation(summary = "Update a subsphere's names/sort order")
    @ApiResponse(responseCode = "200", description = "Subsphere updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/subspheres/{id}")
    @PlatformAdminOnly
    public SubsphereResponse updateSubsphere(@PathVariable UUID id, @Valid @RequestBody UpdateSubsphereRequest request) {
        return catalogAdminService.updateSubsphere(actorId(), actorEmail(), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a subsphere")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/subspheres/{id}/status")
    @PlatformAdminOnly
    public SubsphereResponse setSubsphereStatus(@PathVariable UUID id, @Valid @RequestBody SetStatusRequest request) {
        return catalogAdminService.setSubsphereStatus(actorId(), actorEmail(), id, request);
    }

    // ---- CatalogService --------------------------------------------------

    @Operation(summary = "List a business type's catalog services, any status", description = "The admin-only "
            + "counterpart of GET /api/v1/business-types/{id}/services — see listAllCategories.")
    @ApiResponse(responseCode = "200", description = "Every catalog service under this business type")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", description = "The business type doesn't exist.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/business-types/{id}/services")
    public List<CatalogServiceResponse> listAllCatalogServices(@PathVariable UUID id) {
        PlatformCurrentAdmin.requireAdminId();
        return catalogAdminService.listAllCatalogServices(id);
    }

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
    @PlatformAdminOnly
    public CatalogServiceResponse createCatalogService(@Valid @RequestBody CreateCatalogServiceRequest request) {
        return catalogAdminService.createCatalogService(actorId(), actorEmail(), request);
    }

    @Operation(summary = "Update a catalog service's names/sort order")
    @ApiResponse(responseCode = "200", description = "Catalog service updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/services/{id}")
    @PlatformAdminOnly
    public CatalogServiceResponse updateCatalogService(@PathVariable UUID id,
            @Valid @RequestBody UpdateCatalogServiceRequest request) {
        return catalogAdminService.updateCatalogService(actorId(), actorEmail(), id, request);
    }

    @Operation(summary = "Activate, deactivate, or archive a catalog service")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't PLATFORM_ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/platform/services/{id}/status")
    @PlatformAdminOnly
    public CatalogServiceResponse setCatalogServiceStatus(@PathVariable UUID id,
            @Valid @RequestBody SetStatusRequest request) {
        return catalogAdminService.setCatalogServiceStatus(actorId(), actorEmail(), id,
                request);
    }

    // ---- caller resolution ------------------------------------------

    private UUID actorId() {
        UUID adminId = PlatformCurrentAdmin.requireAdminId();
        return adminId;
    }

    private String actorEmail() {
        return platformAdminService.me(PlatformCurrentAdmin.requireAdminId()).email();
    }
}
