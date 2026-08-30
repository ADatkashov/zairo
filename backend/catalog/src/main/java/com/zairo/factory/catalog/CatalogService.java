package com.zairo.factory.catalog;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Bottom of the master catalog — a standardized service template ("Manicure"),
 * distinct from {@code services.ServiceOffering} (what one specific business
 * actually charges/offers). Named {@code CatalogService}, not {@code Service},
 * for the same reason {@code ServiceOffering} avoided that name: the
 * {@code service} table already belongs to {@code ServiceOffering} (see its
 * own doc comment) — a second entity named {@code Service} would collide
 * both as a SQL table name and as a Java class colliding with Spring's
 * {@code @Service} stereotype.
 */
@Entity
@Table(name = "catalog_service")
public class CatalogService {

    @Id
    private UUID id;

    @Column(name = "business_type_id", nullable = false)
    private UUID businessTypeId;

    // Optional — a service can attach directly under its business type
    // (every pre-4th-level row does, and still may) or, once one exists,
    // under a more specific Subsphere. See Subsphere's own doc comment.
    @Column(name = "subsphere_id")
    private UUID subsphereId;

    @Column(name = "name_kk", nullable = false)
    private String nameKk;

    @Column(name = "name_ru", nullable = false)
    private String nameRu;

    @Column(name = "name_en", nullable = false)
    private String nameEn;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TaxonomyStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected CatalogService() {
    }

    public CatalogService(UUID id, UUID businessTypeId, String nameKk, String nameRu, String nameEn, int sortOrder,
            TaxonomyStatus status, Instant now) {
        this(id, businessTypeId, null, nameKk, nameRu, nameEn, sortOrder, status, now);
    }

    public CatalogService(UUID id, UUID businessTypeId, UUID subsphereId, String nameKk, String nameRu, String nameEn,
            int sortOrder, TaxonomyStatus status, Instant now) {
        this.id = id;
        this.businessTypeId = businessTypeId;
        this.subsphereId = subsphereId;
        this.nameKk = nameKk;
        this.nameRu = nameRu;
        this.nameEn = nameEn;
        this.sortOrder = sortOrder;
        this.status = status;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBusinessTypeId() {
        return businessTypeId;
    }

    public UUID getSubsphereId() {
        return subsphereId;
    }

    public String getNameKk() {
        return nameKk;
    }

    public String getNameRu() {
        return nameRu;
    }

    public String getNameEn() {
        return nameEn;
    }

    public int getSortOrder() {
        return sortOrder;
    }

    public TaxonomyStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    void update(String nameKk, String nameRu, String nameEn, int sortOrder, Instant now) {
        this.nameKk = nameKk;
        this.nameRu = nameRu;
        this.nameEn = nameEn;
        this.sortOrder = sortOrder;
        this.updatedAt = now;
    }

    void setStatus(TaxonomyStatus status, Instant now) {
        this.status = status;
        this.updatedAt = now;
    }
}
