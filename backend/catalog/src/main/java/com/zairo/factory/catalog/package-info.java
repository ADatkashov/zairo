/**
 * Platform master catalog: {@code Category -> BusinessType -> Subsphere ->
 * CatalogService} (Subsphere optional — a CatalogService may attach directly
 * under its BusinessType instead), the admin-curated marketplace taxonomy
 * businesses select from — not a business's own offering (see
 * {@code services.ServiceOffering}). Every level is a plain CRUD entity
 * mutated only through {@link CatalogAdminController} (PLATFORM_ADMIN-only)
 * — a new category, sphere, subsphere, or service is a data change, never a
 * code change or a release. Referenced by id only from
 * {@code providers.Provider} and {@code services.ServiceOffering}, the same
 * cross-module convention every other bounded context in this codebase uses.
 */
package com.zairo.factory.catalog;
