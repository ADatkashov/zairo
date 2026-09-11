package com.zairo.factory.smartfill;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CandidateOfferRepository extends JpaRepository<CandidateOffer, UUID> {

    List<CandidateOffer> findByCampaignId(UUID campaignId);

    List<CandidateOffer> findByCampaignIdAndStage(UUID campaignId, int stage);

    List<CandidateOffer> findByCampaignIdAndStatusIn(UUID campaignId, List<CandidateOfferStatus> statuses);

    List<CandidateOffer> findByUserIdOrderByCreatedAtDesc(UUID userId);

    /** {@link NotificationPolicy}'s daily/weekly frequency limit -- how many times this user was notified since a cutoff. */
    long countByUserIdAndNotifiedAtAfter(UUID userId, Instant cutoff);

    /** {@link NotificationPolicy}'s per-business cooldown -- was this user notified by this provider since a cutoff. */
    boolean existsByUserIdAndProviderIdAndNotifiedAtAfter(UUID userId, UUID providerId, Instant cutoff);

    /**
     * {@link NotificationPolicy}'s decline cooldown. No endpoint sets
     * DECLINED today (see {@link CandidateOfferStatus#DECLINED}'s own doc
     * comment) -- this method exists so that policy check is already wired
     * up and needs no repository change the day a real "not interested"
     * action is added.
     */
    boolean existsByUserIdAndProviderIdAndStatusAndRespondedAtAfter(UUID userId, UUID providerId,
            CandidateOfferStatus status, Instant cutoff);
}
