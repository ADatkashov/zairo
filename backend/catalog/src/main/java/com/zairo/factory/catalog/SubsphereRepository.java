package com.zairo.factory.catalog;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubsphereRepository extends JpaRepository<Subsphere, UUID> {

    Optional<Subsphere> findByCode(String code);

    List<Subsphere> findByBusinessTypeIdAndStatusOrderBySortOrderAsc(UUID businessTypeId, TaxonomyStatus status);

    /** The Platform Admin taxonomy screen's own list — every status, not just ACTIVE. */
    List<Subsphere> findByBusinessTypeIdOrderBySortOrderAsc(UUID businessTypeId);
}
