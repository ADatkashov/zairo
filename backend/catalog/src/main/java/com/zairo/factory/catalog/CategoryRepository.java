package com.zairo.factory.catalog;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategoryRepository extends JpaRepository<Category, UUID> {

    Optional<Category> findByCode(String code);

    List<Category> findByStatusOrderBySortOrderAsc(TaxonomyStatus status);

    /** The Platform Admin taxonomy screen's own list — every status, not just ACTIVE (see CatalogController's doc comment). */
    List<Category> findAllByOrderBySortOrderAsc();
}
