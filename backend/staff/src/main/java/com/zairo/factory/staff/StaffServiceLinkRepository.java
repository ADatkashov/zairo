package com.zairo.factory.staff;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface StaffServiceLinkRepository extends JpaRepository<StaffServiceLink, UUID> {

    List<StaffServiceLink> findByStaffId(UUID staffId);

    boolean existsByStaffIdAndServiceId(UUID staffId, UUID serviceId);

    @Transactional
    void deleteByStaffIdAndServiceId(UUID staffId, UUID serviceId);
}
