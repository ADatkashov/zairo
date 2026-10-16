package com.zairo.factory.workforce;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface FavoriteWorkerRepository extends JpaRepository<FavoriteWorker, UUID> {

    Optional<FavoriteWorker> findByUserIdAndWorkerId(UUID userId, UUID workerId);

    /** Newest first. */
    List<FavoriteWorker> findByUserIdOrderByCreatedAtDesc(UUID userId);

    @Transactional
    void deleteByUserIdAndWorkerId(UUID userId, UUID workerId);

    /** Account deletion. */
    @Transactional
    void deleteByUserId(UUID userId);
}
