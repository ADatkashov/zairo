package com.zairo.factory.payments;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CommissionRateRepository extends JpaRepository<CommissionRate, UUID> {

    Optional<CommissionRate> findByCategoryId(UUID categoryId);

    Optional<CommissionRate> findByCategoryIdIsNull();
}
