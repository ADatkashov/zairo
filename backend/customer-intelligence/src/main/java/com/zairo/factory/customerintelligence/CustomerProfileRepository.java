package com.zairo.factory.customerintelligence;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerProfileRepository extends JpaRepository<CustomerProfile, UUID> {

    /** Account deletion: derived behaviour data about this customer. */
    void deleteByUserId(UUID userId);


    Optional<CustomerProfile> findByUserId(UUID userId);
}
