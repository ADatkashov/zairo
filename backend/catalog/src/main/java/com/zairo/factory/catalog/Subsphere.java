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
 * One level under {@link BusinessType} — "Barbershop" (a business type)
 * might break down into subspheres like "Classic Barbering" and "Beard
 * Grooming". Optional: a {@link CatalogService} can attach directly to a
 * business type when no subsphere exists yet for it (see that entity's own
 * nullable {@code subsphereId}). Same structural shape as {@link BusinessType}
 * on purpose — see that class's own doc comment for why a shared shape
 * doesn't warrant a shared superclass here.
 */
@Entity
@Table(name = "subsphere")
public class Subsphere {

    @Id
    private UUID id;

    @Column(name = "business_type_id", nullable = false)
    private UUID businessTypeId;

    @Column(nullable = false, unique = true)
    private String code;

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

    protected Subsphere() {
    }

    public Subsphere(UUID id, UUID businessTypeId, String code, String nameKk, String nameRu, String nameEn,
            int sortOrder, TaxonomyStatus status, Instant now) {
        this.id = id;
        this.businessTypeId = businessTypeId;
        this.code = code;
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

    public String getCode() {
        return code;
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
