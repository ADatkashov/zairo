package com.zairo.factory.workforce;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerTimeOffRepository extends JpaRepository<WorkerTimeOff, UUID> {

    /** Time off that hasn't ended yet. */
    List<WorkerTimeOff> findByWorkerIdAndEndsAtAfterOrderByStartsAt(UUID workerId, Instant after);

    List<WorkerTimeOff> findByProviderIdAndEndsAtAfterOrderByStartsAt(UUID providerId, Instant after);

    /** Every time off that hasn't ended yet, across all businesses. */
    List<WorkerTimeOff> findByEndsAtAfter(Instant after);

    List<WorkerTimeOff> findByWorkerIdInAndEndsAtAfter(Collection<UUID> workerIds, Instant after);
}
