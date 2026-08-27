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
 * One level under {@link Category} — "Beauty Salon", "Barbershop". References
 * {@code categoryId} by bare id, not a JPA relationship, matching this
 * codebase's cross-entity convention throughout (see e.g.
 * {@code providers.Provider.ownerUserId}). {@code code} is what
 * {@code provider.business_type_id} gets backfilled from, keyed off the
 * existing {@code provider.vertical} string.
 */
@Entity
@Table(name = "business_type")
public class BusinessType {

    @Id
    private UUID id;

    @Column(name = "category_id", nullable = false)
    private UUID categoryId;

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

    protected BusinessType() {
    }

    public BusinessType(UUID id, UUID categoryId, String code, String nameKk, String nameRu, String nameEn,
            int sortOrder, TaxonomyStatus status, Instant now) {
        this.id = id;
        this.categoryId = categoryId;
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

    public UUID getCategoryId() {
        return categoryId;
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
