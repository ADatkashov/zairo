package com.zairo.factory.catalog;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CatalogServiceRepository extends JpaRepository<CatalogService, UUID> {

    List<CatalogService> findByBusinessTypeIdAndStatusOrderBySortOrderAsc(UUID businessTypeId, TaxonomyStatus status);
}
