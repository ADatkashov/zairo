package com.zairo.factory.workforce;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerBookingStateRepository extends JpaRepository<WorkerBookingState, UUID> {

    /** Declines the owner hasn't resolved yet (the booking-status filter is applied by the caller). */
    List<WorkerBookingState> findByWorkerIdInAndDeclinedAtIsNotNull(Collection<UUID> workerIds);
}
