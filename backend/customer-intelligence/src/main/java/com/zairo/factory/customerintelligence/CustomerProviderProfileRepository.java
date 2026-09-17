package com.zairo.factory.customerintelligence;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerProviderProfileRepository extends JpaRepository<CustomerProviderProfile, UUID> {

    Optional<CustomerProviderProfile> findByUserIdAndProviderId(UUID userId, UUID providerId);

    /**
     * {@code CustomerIntelligenceService#findProviderProfiles}'s bulk read
     * for a whole candidate pool -- one query, not one {@link
     * #findByUserIdAndProviderId} call per candidate, same "no N+1"
     * discipline {@code smartfill.CandidateFinder}'s own bulk fetches
     * already follow.
     */
    List<CustomerProviderProfile> findByProviderIdAndUserIdIn(UUID providerId, Collection<UUID> userIds);

    List<CustomerProviderProfile> findByProviderId(UUID providerId);
}
