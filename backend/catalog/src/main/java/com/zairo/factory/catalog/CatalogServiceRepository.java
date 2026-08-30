package com.zairo.factory.catalog;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CatalogServiceRepository extends JpaRepository<CatalogService, UUID> {

    List<CatalogService> findByBusinessTypeIdAndStatusOrderBySortOrderAsc(UUID businessTypeId, TaxonomyStatus status);

    List<CatalogService> findBySubsphereIdAndStatusOrderBySortOrderAsc(UUID subsphereId, TaxonomyStatus status);

    // A derived findByNameKkContainingOrNameRuContainingOrNameEnContaining
    // method would work too, but doesn't read as clearly as this once
    // IgnoreCase is added on all three — one JPQL query with explicit
    // lower()/like is what booking/reviews already reach for in this
    // codebase when a derived method gets awkward (see e.g.
    // ReviewRepository.aggregateRatingsByProviderIds).
    @Query("select c from CatalogService c where lower(c.nameKk) like lower(concat('%', :query, '%')) "
            + "or lower(c.nameRu) like lower(concat('%', :query, '%')) "
            + "or lower(c.nameEn) like lower(concat('%', :query, '%'))")
    List<CatalogService> findByAnyNameContainingIgnoreCase(@Param("query") String query);
}
