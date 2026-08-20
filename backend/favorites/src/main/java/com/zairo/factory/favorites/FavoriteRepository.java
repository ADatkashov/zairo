package com.zairo.factory.favorites;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface FavoriteRepository extends JpaRepository<Favorite, UUID> {

    Optional<Favorite> findByUserIdAndProviderId(UUID userId, UUID providerId);

    List<Favorite> findByUserId(UUID userId);

    @Transactional
    void deleteByUserIdAndProviderId(UUID userId, UUID providerId);
}
