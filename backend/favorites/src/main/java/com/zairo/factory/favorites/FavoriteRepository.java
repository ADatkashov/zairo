package com.zairo.factory.favorites;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface FavoriteRepository extends JpaRepository<Favorite, UUID> {

    Optional<Favorite> findByUserIdAndProviderId(UUID userId, UUID providerId);

    List<Favorite> findByUserId(UUID userId);

    /** Every customer who favorited this provider — smart-fill's "follows this business" candidate signal. */
    List<Favorite> findByProviderId(UUID providerId);

    @Transactional
    void deleteByUserIdAndProviderId(UUID userId, UUID providerId);

    /** Account deletion. */
    void deleteByUserId(UUID userId);
}
