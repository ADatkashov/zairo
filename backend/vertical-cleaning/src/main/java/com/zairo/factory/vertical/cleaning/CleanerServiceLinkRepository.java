package com.zairo.factory.vertical.cleaning;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface CleanerServiceLinkRepository extends JpaRepository<CleanerServiceLink, UUID> {

    List<CleanerServiceLink> findByCleanerId(UUID cleanerId);

    boolean existsByCleanerIdAndServiceId(UUID cleanerId, UUID serviceId);

    @Transactional
    void deleteByCleanerIdAndServiceId(UUID cleanerId, UUID serviceId);
}
