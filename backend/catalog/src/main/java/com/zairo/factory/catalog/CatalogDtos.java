package com.zairo.factory.catalog;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public final class CatalogDtos {

    private CatalogDtos() {
    }

    // Lowercase/digits/underscore only — a slug meant for code and API
    // consumers, never shown to a user, so it doesn't need its own
    // localization the way the name fields do.
    private static final String CODE_PATTERN = "^[a-z][a-z0-9_]*$";

    public record CreateCategoryRequest(
            @NotBlank @Size(max = 50) @Pattern(regexp = CODE_PATTERN) @Schema(example = "beauty") String code,
            @NotBlank @Size(max = 255) @Schema(example = "Сұлулық") String nameKk,
            @NotBlank @Size(max = 255) @Schema(example = "Красота") String nameRu,
            @NotBlank @Size(max = 255) @Schema(example = "Beauty") String nameEn,
            @Schema(description = "Optional single emoji shown in the category grid.", example = "💇") String icon,
            @Schema(example = "1") int sortOrder) {
    }

    public record UpdateCategoryRequest(
            @NotBlank @Size(max = 255) String nameKk,
            @NotBlank @Size(max = 255) String nameRu,
            @NotBlank @Size(max = 255) String nameEn,
            String icon,
            int sortOrder) {
    }

    public record CreateBusinessTypeRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID categoryId,
            @NotBlank @Size(max = 50) @Pattern(regexp = CODE_PATTERN) @Schema(example = "beauty_salon") String code,
            @NotBlank @Size(max = 255) @Schema(example = "Сұлулық салоны") String nameKk,
            @NotBlank @Size(max = 255) @Schema(example = "Салон красоты") String nameRu,
            @NotBlank @Size(max = 255) @Schema(example = "Beauty Salon") String nameEn,
            @Schema(example = "1") int sortOrder) {
    }

    public record UpdateBusinessTypeRequest(
            @NotBlank @Size(max = 255) String nameKk,
            @NotBlank @Size(max = 255) String nameRu,
            @NotBlank @Size(max = 255) String nameEn,
            int sortOrder) {
    }

    public record CreateCatalogServiceRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID businessTypeId,
            @Schema(description = "Optional — attach under this Subsphere instead of directly under "
                    + "businessTypeId. Must belong to businessTypeId.",
                    example = "550e8400-e29b-41d4-a716-446655440000") UUID subsphereId,
            @NotBlank @Size(max = 255) @Schema(example = "Маникюр") String nameKk,
            @NotBlank @Size(max = 255) @Schema(example = "Маникюр") String nameRu,
            @NotBlank @Size(max = 255) @Schema(example = "Manicure") String nameEn,
            @Schema(example = "1") int sortOrder) {
    }

    public record UpdateCatalogServiceRequest(
            @NotBlank @Size(max = 255) String nameKk,
            @NotBlank @Size(max = 255) String nameRu,
            @NotBlank @Size(max = 255) String nameEn,
            int sortOrder) {
    }

    public record CreateSubsphereRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID businessTypeId,
            @NotBlank @Size(max = 50) @Pattern(regexp = CODE_PATTERN) @Schema(example = "beard_grooming") String code,
            @NotBlank @Size(max = 255) @Schema(example = "Сақалды күтім") String nameKk,
            @NotBlank @Size(max = 255) @Schema(example = "Уход за бородой") String nameRu,
            @NotBlank @Size(max = 255) @Schema(example = "Beard Grooming") String nameEn,
            @Schema(example = "1") int sortOrder) {
    }

    public record UpdateSubsphereRequest(
            @NotBlank @Size(max = 255) String nameKk,
            @NotBlank @Size(max = 255) String nameRu,
            @NotBlank @Size(max = 255) String nameEn,
            int sortOrder) {
    }

    public record SetStatusRequest(
            @NotNull @Schema(example = "ACTIVE") TaxonomyStatus status,
            @Schema(description = "Recorded on the audit log entry for this action.") String reason) {
    }

    public record CategoryResponse(
            UUID id, String code, String nameKk, String nameRu, String nameEn, String icon, int sortOrder,
            TaxonomyStatus status) {
        static CategoryResponse from(Category category) {
            return new CategoryResponse(category.getId(), category.getCode(), category.getNameKk(),
                    category.getNameRu(), category.getNameEn(), category.getIcon(), category.getSortOrder(),
                    category.getStatus());
        }
    }

    public record BusinessTypeResponse(
            UUID id, UUID categoryId, String code, String nameKk, String nameRu, String nameEn, int sortOrder,
            TaxonomyStatus status) {
        static BusinessTypeResponse from(BusinessType businessType) {
            return new BusinessTypeResponse(businessType.getId(), businessType.getCategoryId(),
                    businessType.getCode(), businessType.getNameKk(), businessType.getNameRu(),
                    businessType.getNameEn(), businessType.getSortOrder(), businessType.getStatus());
        }
    }

    public record CatalogServiceResponse(
            UUID id, UUID businessTypeId, UUID subsphereId, String nameKk, String nameRu, String nameEn,
            int sortOrder, TaxonomyStatus status) {
        static CatalogServiceResponse from(CatalogService service) {
            return new CatalogServiceResponse(service.getId(), service.getBusinessTypeId(), service.getSubsphereId(),
                    service.getNameKk(), service.getNameRu(), service.getNameEn(), service.getSortOrder(),
                    service.getStatus());
        }
    }

    public record SubsphereResponse(
            UUID id, UUID businessTypeId, String code, String nameKk, String nameRu, String nameEn, int sortOrder,
            TaxonomyStatus status) {
        static SubsphereResponse from(Subsphere subsphere) {
            return new SubsphereResponse(subsphere.getId(), subsphere.getBusinessTypeId(), subsphere.getCode(),
                    subsphere.getNameKk(), subsphere.getNameRu(), subsphere.getNameEn(), subsphere.getSortOrder(),
                    subsphere.getStatus());
        }
    }
}
