/**
 * Platform master catalog: {@code Category -> BusinessType -> CatalogService}, the
 * admin-curated marketplace taxonomy businesses select from — not a business's own
 * offering (see {@code services.ServiceOffering}). Referenced by id only from
 * {@code providers.Provider} and {@code services.ServiceOffering}, the same
 * cross-module convention every other bounded context in this codebase uses.
 */
package com.zairo.factory.catalog;
