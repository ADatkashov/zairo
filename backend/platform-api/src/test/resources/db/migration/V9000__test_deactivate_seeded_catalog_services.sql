-- Test-only. V94 seeds ACTIVE starter catalog services, and from then on
-- ServiceCatalogPolicy rejects free-text services for those business types.
-- Most e2e tests create free-text services under the seeded "beauty"/"auto"/...
-- verticals, so the seeded services are switched off here; the tests that
-- verify the seed itself (CatalogApiTests) switch them back on for their own
-- duration, and ServiceCatalogApiTests builds its own catalog.
update catalog_service set status = 'INACTIVE';
