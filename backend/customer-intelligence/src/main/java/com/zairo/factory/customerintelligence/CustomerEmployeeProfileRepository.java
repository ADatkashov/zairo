package com.zairo.factory.customerintelligence;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerEmployeeProfileRepository extends JpaRepository<CustomerEmployeeProfile, UUID> {

    /** Account deletion: derived behaviour data about this customer. */
    void deleteByUserId(UUID userId);


    Optional<CustomerEmployeeProfile> findByUserIdAndProviderIdAndEmployeeId(UUID userId, UUID providerId,
            UUID employeeId);
}
