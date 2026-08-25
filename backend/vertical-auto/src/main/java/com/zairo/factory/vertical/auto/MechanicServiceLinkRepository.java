package com.zairo.factory.vertical.auto;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface MechanicServiceLinkRepository extends JpaRepository<MechanicServiceLink, UUID> {

    List<MechanicServiceLink> findByMechanicId(UUID mechanicId);

    boolean existsByMechanicIdAndServiceId(UUID mechanicId, UUID serviceId);

    @Transactional
    void deleteByMechanicIdAndServiceId(UUID mechanicId, UUID serviceId);
}
