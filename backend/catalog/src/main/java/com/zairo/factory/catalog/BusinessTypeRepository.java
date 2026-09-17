package com.zairo.factory.catalog;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusinessTypeRepository extends JpaRepository<BusinessType, UUID> {

    Optional<BusinessType> findByCode(String code);

    List<BusinessType> findByCategoryIdAndStatusOrderBySortOrderAsc(UUID categoryId, TaxonomyStatus status);

    /** The Platform Admin taxonomy screen's own list — every status, not just ACTIVE. */
    List<BusinessType> findByCategoryIdOrderBySortOrderAsc(UUID categoryId);
}
