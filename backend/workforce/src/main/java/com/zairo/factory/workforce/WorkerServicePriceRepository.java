package com.zairo.factory.workforce;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerServicePriceRepository extends JpaRepository<WorkerServicePrice, UUID> {

    List<WorkerServicePrice> findByWorkerId(UUID workerId);

    List<WorkerServicePrice> findByProviderIdAndServiceId(UUID providerId, UUID serviceId);

    Optional<WorkerServicePrice> findByWorkerIdAndServiceId(UUID workerId, UUID serviceId);
}
