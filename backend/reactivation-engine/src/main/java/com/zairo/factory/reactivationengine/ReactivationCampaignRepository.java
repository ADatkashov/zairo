package com.zairo.factory.reactivationengine;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReactivationCampaignRepository extends JpaRepository<ReactivationCampaign, UUID> {

    /**
     * The daily sweep's duplicate-protection -- and, since a still-inactive
     * pair keeps re-appearing in every day's sweep until they book again,
     * this is what makes the whole sweep idempotent (see this module's
     * package-info). Also the application-layer guard alongside the unique
     * index on the same column.
     */
    boolean existsByLastVisitBookingId(UUID lastVisitBookingId);

    /** {@link ReactivationCampaignJob}'s sweep target for a SENT campaign whose follow-up window has closed unbooked. */
    List<ReactivationCampaign> findByStatusAndExpiresAtLessThanEqual(ReactivationCampaignStatus status,
            Instant cutoff);

    /**
     * {@link ReactivationOutcomeListener}'s lookup -- every still-active
     * campaign for this exact customer+provider pair, closed out the
     * moment that customer books again. A list rather than assuming at
     * most one, same defensive reasoning as {@code
     * rebookengine.RebookCampaignRepository#findByUserIdAndProviderIdAndStatusIn}.
     */
    List<ReactivationCampaign> findByUserIdAndProviderIdAndStatus(UUID userId, UUID providerId,
            ReactivationCampaignStatus status);

    /** {@code campaigncenter.CampaignCenterService}'s Campaign Center read surface -- every Reactivation campaign this provider has ever run. */
    List<ReactivationCampaign> findByProviderId(UUID providerId);

    /** The same read surface's date-scoped variant -- the Campaign Center's selected date-range filter. */
    List<ReactivationCampaign> findByProviderIdAndCreatedAtBetween(UUID providerId, Instant from, Instant to);
}
