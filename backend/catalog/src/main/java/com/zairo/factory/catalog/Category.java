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
 * Top of the master catalog — "Beauty", "Auto". {@code code} is a stable,
 * non-localized slug ({@code "beauty"}) distinct from the display names —
 * used for the one-time {@code provider.vertical} backfill and by clients
 * that need a fixed reference instead of a language-dependent string.
 */
@Entity
@Table(name = "category")
public class Category {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private String code;

    @Column(name = "name_kk", nullable = false)
    private String nameKk;

    @Column(name = "name_ru", nullable = false)
    private String nameRu;

    @Column(name = "name_en", nullable = false)
    private String nameEn;

    // A single emoji (or null) rendered next to this category in the
    // discovery UI's category grid — nullable, older categories predate it.
    @Column
    private String icon;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TaxonomyStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Category() {
    }

    public Category(UUID id, String code, String nameKk, String nameRu, String nameEn, int sortOrder,
            TaxonomyStatus status, Instant now) {
        this(id, code, nameKk, nameRu, nameEn, null, sortOrder, status, now);
    }

    public Category(UUID id, String code, String nameKk, String nameRu, String nameEn, String icon, int sortOrder,
            TaxonomyStatus status, Instant now) {
        this.id = id;
        this.code = code;
        this.nameKk = nameKk;
        this.nameRu = nameRu;
        this.nameEn = nameEn;
        this.icon = icon;
        this.sortOrder = sortOrder;
        this.status = status;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
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

    public String getIcon() {
        return icon;
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

    void update(String nameKk, String nameRu, String nameEn, String icon, int sortOrder, Instant now) {
        this.nameKk = nameKk;
        this.nameRu = nameRu;
        this.nameEn = nameEn;
        this.icon = icon;
        this.sortOrder = sortOrder;
        this.updatedAt = now;
    }

    void setStatus(TaxonomyStatus status, Instant now) {
        this.status = status;
        this.updatedAt = now;
    }
}
