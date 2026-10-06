package com.zairo.factory.workforce;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerWorkHoursRepository extends JpaRepository<WorkerWorkHours, UUID> {

    List<WorkerWorkHours> findByWorkerId(UUID workerId);

    List<WorkerWorkHours> findByWorkerIdIn(Collection<UUID> workerIds);

    void deleteByWorkerId(UUID workerId);
}
