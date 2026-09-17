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

    /** {@code campaigncenter.CampaignCenterService}'s Campaign Center read surface -- every Rebook campaign this provider has ever run. */
    List<RebookCampaign> findByProviderId(UUID providerId);

    /** The same read surface's date-scoped variant -- the Campaign Center's selected date-range filter. */
    List<RebookCampaign> findByProviderIdAndCreatedAtBetween(UUID providerId, Instant from, Instant to);

    /**
     * Automation Center's cooldown guard -- true if this customer already
     * got a Rebook nudge from this provider more recently than the
     * configured cooldown, regardless of that campaign's current status
     * (even a since-expired/cancelled one still counts as "already nudged
     * them recently").
     */
    boolean existsByUserIdAndProviderIdAndCreatedAtGreaterThan(UUID userId, UUID providerId, Instant since);
}
