package com.zairo.factory.vertical.beauty;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface MasterServiceLinkRepository extends JpaRepository<MasterServiceLink, UUID> {

    List<MasterServiceLink> findByMasterId(UUID masterId);

    boolean existsByMasterIdAndServiceId(UUID masterId, UUID serviceId);

    @Transactional
    void deleteByMasterIdAndServiceId(UUID masterId, UUID serviceId);
}
