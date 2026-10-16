package com.zairo.factory.catalog;

import com.zairo.factory.catalog.CatalogDtos.BusinessTypeResponse;
import com.zairo.factory.catalog.CatalogDtos.CatalogServiceResponse;
import com.zairo.factory.catalog.CatalogDtos.CategoryResponse;
import com.zairo.factory.catalog.CatalogDtos.SubsphereResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/**
 * The public, unauthenticated read side of the master catalog — what
 * discovery UIs (the category row on Home, a future "browse by category"
 * screen) call. Mutation lives in {@link CatalogAdminController} instead,
 * PLATFORM_ADMIN-only. Every list here is ACTIVE-only, ordered by
 * {@code sortOrder} — INACTIVE/ARCHIVED entries exist only for admin views.
 */
@RestController
@Tag(name = "Catalog")
public class CatalogController {

    private final CategoryRepository categoryRepository;
    private final BusinessTypeRepository businessTypeRepository;
    private final SubsphereRepository subsphereRepository;
    private final CatalogServiceRepository catalogServiceRepository;

    public CatalogController(CategoryRepository categoryRepository, BusinessTypeRepository businessTypeRepository,
            SubsphereRepository subsphereRepository, CatalogServiceRepository catalogServiceRepository) {
        this.categoryRepository = categoryRepository;
        this.businessTypeRepository = businessTypeRepository;
        this.subsphereRepository = subsphereRepository;
        this.catalogServiceRepository = catalogServiceRepository;
    }

    @Operation(summary = "List active categories", description = "The top level of the master catalog, ordered "
            + "by sortOrder. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Active categories")
    @GetMapping("/api/v1/categories")
    public List<CategoryResponse> listCategories() {
        return categoryRepository.findByStatusOrderBySortOrderAsc(TaxonomyStatus.ACTIVE).stream()
                .map(CategoryResponse::from).toList();
    }

    @Operation(summary = "List a category's active business types")
    @ApiResponse(responseCode = "200", description = "Active business types under this category")
    @GetMapping("/api/v1/categories/{id}/business-types")
    public List<BusinessTypeResponse> listBusinessTypes(
            @Parameter(description = "The category's id.") @PathVariable UUID id) {
        return businessTypeRepository.findByCategoryIdAndStatusOrderBySortOrderAsc(id, TaxonomyStatus.ACTIVE)
                .stream().map(BusinessTypeResponse::from).toList();
    }

    @Operation(summary = "List a business type's active subspheres", description = "Optional 4th catalog "
            + "level — may be empty for a business type with no further breakdown yet.")
    @ApiResponse(responseCode = "200", description = "Active subspheres under this business type")
    @GetMapping("/api/v1/business-types/{id}/subspheres")
    public List<SubsphereResponse> listSubspheres(
            @Parameter(description = "The business type's id.") @PathVariable UUID id) {
        return subsphereRepository.findByBusinessTypeIdAndStatusOrderBySortOrderAsc(id, TaxonomyStatus.ACTIVE)
                .stream().map(SubsphereResponse::from).toList();
    }

    @Operation(summary = "List a business type's active catalog services", description = "Every active "
            + "service of the business type, including those grouped under one of its subspheres (see each "
            + "service's subsphereId) — GET /subspheres/{id}/services narrows to a single subsphere.")
    @ApiResponse(responseCode = "200", description = "Active catalog services under this business type")
    @GetMapping("/api/v1/business-types/{id}/services")
    public List<CatalogServiceResponse> listCatalogServices(
            @Parameter(description = "The business type's id.") @PathVariable UUID id) {
        return catalogServiceRepository.findByBusinessTypeIdAndStatusOrderBySortOrderAsc(id, TaxonomyStatus.ACTIVE)
                .stream().map(CatalogServiceResponse::from).toList();
    }

    @Operation(summary = "List a subsphere's active catalog services")
    @ApiResponse(responseCode = "200", description = "Active catalog services under this subsphere")
    @GetMapping("/api/v1/subspheres/{id}/services")
    public List<CatalogServiceResponse> listCatalogServicesBySubsphere(
            @Parameter(description = "The subsphere's id.") @PathVariable UUID id) {
        return catalogServiceRepository.findBySubsphereIdAndStatusOrderBySortOrderAsc(id, TaxonomyStatus.ACTIVE)
                .stream().map(CatalogServiceResponse::from).toList();
    }
}
