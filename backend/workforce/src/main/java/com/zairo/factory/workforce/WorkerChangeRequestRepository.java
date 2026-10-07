package com.zairo.factory.workforce;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerChangeRequestRepository extends JpaRepository<WorkerChangeRequest, UUID> {

    List<WorkerChangeRequest> findByProviderIdAndStatus(UUID providerId, WorkerChangeRequest.Status status);

    List<WorkerChangeRequest> findByBookingIdInAndStatus(Collection<UUID> bookingIds, WorkerChangeRequest.Status status);
}
