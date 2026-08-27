package com.zairo.factory.catalog;

/**
 * Content-management lifecycle, distinct from {@code providers.ProviderStatus}'s
 * approval workflow (PENDING/ACTIVE/SUSPENDED) — a catalog entry doesn't get
 * "approved," an admin publishes it (ACTIVE), hides it without deleting
 * (INACTIVE — still valid for existing references), or retires it for good
 * (ARCHIVED). Shared across Category/BusinessType/CatalogService since all
 * three need identical lifecycle semantics, not three near-duplicate enums.
 */
public enum TaxonomyStatus {
    ACTIVE,
    INACTIVE,
    ARCHIVED
}
