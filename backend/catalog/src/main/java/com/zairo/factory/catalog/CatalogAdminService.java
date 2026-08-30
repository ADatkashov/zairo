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
import com.zairo.factory.platformadmin.PlatformAuditLogService;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * One cohesive service for all four catalog levels rather than a
 * per-entity split (which would mean an awkwardly-named
 * {@code CatalogServiceService}) — Category/BusinessType/Subsphere/
 * CatalogService are structurally identical enough (name_kk/ru/en +
 * sortOrder + status) that four near-empty classes would be pure
 * duplication with no real separation of concerns. Every mutation is
 * audit-logged through
 * {@link PlatformAuditLogService}, the same helper platform-admin's own
 * account creation already uses — no second admin-action log.
 */
@Service
public class CatalogAdminService {

    private final CategoryRepository categoryRepository;
    private final BusinessTypeRepository businessTypeRepository;
    private final SubsphereRepository subsphereRepository;
    private final CatalogServiceRepository catalogServiceRepository;
    private final PlatformAuditLogService auditLogService;

    public CatalogAdminService(CategoryRepository categoryRepository, BusinessTypeRepository businessTypeRepository,
            SubsphereRepository subsphereRepository, CatalogServiceRepository catalogServiceRepository,
            PlatformAuditLogService auditLogService) {
        this.categoryRepository = categoryRepository;
        this.businessTypeRepository = businessTypeRepository;
        this.subsphereRepository = subsphereRepository;
        this.catalogServiceRepository = catalogServiceRepository;
        this.auditLogService = auditLogService;
    }

    // ---- Category ----------------------------------------------------

    @Transactional
    public CategoryResponse createCategory(UUID actorId, String actorEmail, CreateCategoryRequest request) {
        if (categoryRepository.findByCode(request.code()).isPresent()) {
            throw new CatalogCodeAlreadyExistsException("Category code already exists: " + request.code());
        }
        Category category = categoryRepository.save(new Category(UUID.randomUUID(), request.code(),
                request.nameKk(), request.nameRu(), request.nameEn(), request.icon(), request.sortOrder(),
                TaxonomyStatus.ACTIVE, Instant.now()));
        auditLogService.record(actorId, actorEmail, "CATEGORY_CREATED", "CATEGORY", category.getId(), null,
                request.code(), null);
        return CategoryResponse.from(category);
    }

    @Transactional
    public CategoryResponse updateCategory(UUID actorId, String actorEmail, UUID id, UpdateCategoryRequest request) {
        Category category = findCategory(id);
        String previous = category.getNameEn();
        category.update(request.nameKk(), request.nameRu(), request.nameEn(), request.icon(), request.sortOrder(),
                Instant.now());
        auditLogService.record(actorId, actorEmail, "CATEGORY_UPDATED", "CATEGORY", id, previous, request.nameEn(),
                null);
        return CategoryResponse.from(category);
    }

    @Transactional
    public CategoryResponse setCategoryStatus(UUID actorId, String actorEmail, UUID id, SetStatusRequest request) {
        Category category = findCategory(id);
        String previous = category.getStatus().name();
        category.setStatus(request.status(), Instant.now());
        auditLogService.record(actorId, actorEmail, "CATEGORY_STATUS_CHANGED", "CATEGORY", id, previous,
                request.status().name(), request.reason());
        return CategoryResponse.from(category);
    }

    // ---- BusinessType --------------------------------------------------

    @Transactional
    public BusinessTypeResponse createBusinessType(UUID actorId, String actorEmail, CreateBusinessTypeRequest request) {
        if (businessTypeRepository.findByCode(request.code()).isPresent()) {
            throw new CatalogCodeAlreadyExistsException("Business type code already exists: " + request.code());
        }
        findCategory(request.categoryId());
        BusinessType businessType = businessTypeRepository.save(new BusinessType(UUID.randomUUID(),
                request.categoryId(), request.code(), request.nameKk(), request.nameRu(), request.nameEn(),
                request.sortOrder(), TaxonomyStatus.ACTIVE, Instant.now()));
        auditLogService.record(actorId, actorEmail, "BUSINESS_TYPE_CREATED", "BUSINESS_TYPE", businessType.getId(),
                null, request.code(), null);
        return BusinessTypeResponse.from(businessType);
    }

    @Transactional
    public BusinessTypeResponse updateBusinessType(UUID actorId, String actorEmail, UUID id,
            UpdateBusinessTypeRequest request) {
        BusinessType businessType = findBusinessType(id);
        String previous = businessType.getNameEn();
        businessType.update(request.nameKk(), request.nameRu(), request.nameEn(), request.sortOrder(),
                Instant.now());
        auditLogService.record(actorId, actorEmail, "BUSINESS_TYPE_UPDATED", "BUSINESS_TYPE", id, previous,
                request.nameEn(), null);
        return BusinessTypeResponse.from(businessType);
    }

    @Transactional
    public BusinessTypeResponse setBusinessTypeStatus(UUID actorId, String actorEmail, UUID id,
            SetStatusRequest request) {
        BusinessType businessType = findBusinessType(id);
        String previous = businessType.getStatus().name();
        businessType.setStatus(request.status(), Instant.now());
        auditLogService.record(actorId, actorEmail, "BUSINESS_TYPE_STATUS_CHANGED", "BUSINESS_TYPE", id, previous,
                request.status().name(), request.reason());
        return BusinessTypeResponse.from(businessType);
    }

    // ---- Subsphere -------------------------------------------------------

    @Transactional
    public SubsphereResponse createSubsphere(UUID actorId, String actorEmail, CreateSubsphereRequest request) {
        if (subsphereRepository.findByCode(request.code()).isPresent()) {
            throw new CatalogCodeAlreadyExistsException("Subsphere code already exists: " + request.code());
        }
        findBusinessType(request.businessTypeId());
        Subsphere subsphere = subsphereRepository.save(new Subsphere(UUID.randomUUID(), request.businessTypeId(),
                request.code(), request.nameKk(), request.nameRu(), request.nameEn(), request.sortOrder(),
                TaxonomyStatus.ACTIVE, Instant.now()));
        auditLogService.record(actorId, actorEmail, "SUBSPHERE_CREATED", "SUBSPHERE", subsphere.getId(), null,
                request.code(), null);
        return SubsphereResponse.from(subsphere);
    }

    @Transactional
    public SubsphereResponse updateSubsphere(UUID actorId, String actorEmail, UUID id,
            UpdateSubsphereRequest request) {
        Subsphere subsphere = findSubsphere(id);
        String previous = subsphere.getNameEn();
        subsphere.update(request.nameKk(), request.nameRu(), request.nameEn(), request.sortOrder(), Instant.now());
        auditLogService.record(actorId, actorEmail, "SUBSPHERE_UPDATED", "SUBSPHERE", id, previous, request.nameEn(),
                null);
        return SubsphereResponse.from(subsphere);
    }

    @Transactional
    public SubsphereResponse setSubsphereStatus(UUID actorId, String actorEmail, UUID id, SetStatusRequest request) {
        Subsphere subsphere = findSubsphere(id);
        String previous = subsphere.getStatus().name();
        subsphere.setStatus(request.status(), Instant.now());
        auditLogService.record(actorId, actorEmail, "SUBSPHERE_STATUS_CHANGED", "SUBSPHERE", id, previous,
                request.status().name(), request.reason());
        return SubsphereResponse.from(subsphere);
    }

    // ---- CatalogService --------------------------------------------------

    @Transactional
    public CatalogServiceResponse createCatalogService(UUID actorId, String actorEmail,
            CreateCatalogServiceRequest request) {
        findBusinessType(request.businessTypeId());
        if (request.subsphereId() != null) {
            Subsphere subsphere = findSubsphere(request.subsphereId());
            if (!subsphere.getBusinessTypeId().equals(request.businessTypeId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Subsphere " + request.subsphereId() + " does not belong to business type "
                                + request.businessTypeId());
            }
        }
        CatalogService service = catalogServiceRepository.save(new CatalogService(UUID.randomUUID(),
                request.businessTypeId(), request.subsphereId(), request.nameKk(), request.nameRu(),
                request.nameEn(), request.sortOrder(), TaxonomyStatus.ACTIVE, Instant.now()));
        auditLogService.record(actorId, actorEmail, "CATALOG_SERVICE_CREATED", "CATALOG_SERVICE", service.getId(),
                null, request.nameEn(), null);
        return CatalogServiceResponse.from(service);
    }

    @Transactional
    public CatalogServiceResponse updateCatalogService(UUID actorId, String actorEmail, UUID id,
            UpdateCatalogServiceRequest request) {
        CatalogService service = findCatalogService(id);
        String previous = service.getNameEn();
        service.update(request.nameKk(), request.nameRu(), request.nameEn(), request.sortOrder(), Instant.now());
        auditLogService.record(actorId, actorEmail, "CATALOG_SERVICE_UPDATED", "CATALOG_SERVICE", id, previous,
                request.nameEn(), null);
        return CatalogServiceResponse.from(service);
    }

    @Transactional
    public CatalogServiceResponse setCatalogServiceStatus(UUID actorId, String actorEmail, UUID id,
            SetStatusRequest request) {
        CatalogService service = findCatalogService(id);
        String previous = service.getStatus().name();
        service.setStatus(request.status(), Instant.now());
        auditLogService.record(actorId, actorEmail, "CATALOG_SERVICE_STATUS_CHANGED", "CATALOG_SERVICE", id,
                previous, request.status().name(), request.reason());
        return CatalogServiceResponse.from(service);
    }

    // ---- lookups --------------------------------------------------------

    private Category findCategory(UUID id) {
        return categoryRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found: " + id));
    }

    private BusinessType findBusinessType(UUID id) {
        return businessTypeRepository.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Business type not found: " + id));
    }

    private Subsphere findSubsphere(UUID id) {
        return subsphereRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Subsphere not found: " + id));
    }

    private CatalogService findCatalogService(UUID id) {
        return catalogServiceRepository.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Catalog service not found: " + id));
    }
}
