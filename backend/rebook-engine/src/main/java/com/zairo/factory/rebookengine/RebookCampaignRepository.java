package com.zairo.factory.rebookengine;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RebookCampaignRepository extends JpaRepository<RebookCampaign, UUID> {

    /** Duplicate-campaign protection at the application layer -- the unique index on the same column is the real guard. */
    boolean existsByCompletedBookingId(UUID completedBookingId);

    Optional<RebookCampaign> findByCompletedBookingId(UUID completedBookingId);

    /** {@link RebookCampaignJob}'s sweep target for CREATED campaigns whose predicted next-visit date has arrived. */
    List<RebookCampaign> findByStatusAndDueAtLessThanEqual(RebookCampaignStatus status, Instant cutoff);

    /** {@link RebookCampaignJob}'s sweep target for OFFERED campaigns whose follow-up window has closed unbooked. */
    List<RebookCampaign> findByStatusAndExpiresAtLessThanEqual(RebookCampaignStatus status, Instant cutoff);

    /**
     * {@link RebookOutcomeListener}'s lookup -- every still-active campaign
     * for this exact customer+provider pair, closed out the moment that
     * customer books again. A list rather than assuming at most one, same
     * defensive reasoning as {@code smartfill.SmartFillCampaignRepository
     * #findByAvailabilitySlotIdAndStatusIn}.
     */
    List<RebookCampaign> findByUserIdAndProviderIdAndStatusIn(UUID userId, UUID providerId,
            List<RebookCampaignStatus> statuses);
}
