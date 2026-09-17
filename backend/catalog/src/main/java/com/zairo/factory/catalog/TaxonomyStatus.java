package com.zairo.factory.catalog;

/**
 * Content-management lifecycle, distinct from {@code providers.ProviderStatus}'s
 * approval workflow (PENDING/ACTIVE/SUSPENDED) — a catalog entry doesn't get
 * "approved," an admin publishes it (ACTIVE), hides it without deleting
 * (INACTIVE — still valid for existing references), or retires it for good
 * (ARCHIVED). Shared across Category/BusinessType/CatalogService since all
 * three need identical lifecycle semantics, not three near-duplicate enums.
 *
 * <p><b>Product rule — deliberately never cascades to {@code Provider.status}:</b>
 * this is a vertical launch/visibility switch, not a moderation action.
 * ZAIRO pre-provisions categories (and real businesses under them) ahead of
 * a vertical's public launch — e.g. Medicine can sit INACTIVE in the
 * database with several ACTIVE clinics already onboarded, invisible to
 * customers only because nothing yet points them at it (see
 * {@link CatalogController}'s ACTIVE-only public reads). Flipping a
 * category ACTIVE↔INACTIVE must only ever change rows in this module's own
 * tables (category/business_type/subsphere/catalog_service) — never touch
 * {@code providers.Provider} in any way, and in particular never write to
 * {@code Provider.status}. If a future requirement needs to actually
 * suspend businesses when their vertical is pulled, that is a distinct,
 * explicit bulk-moderation action for someone to build later — not a side
 * effect of this enum's setter. See {@code CatalogApiTests
 * .deactivatingACategoryNeverChangesAnExistingBusinesssStatusOrDiscoverability}.</p>
 */
public enum TaxonomyStatus {
    ACTIVE,
    INACTIVE,
    ARCHIVED
}
