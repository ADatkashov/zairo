package com.zairo.factory.smartfill;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SmartFillCampaignRepository extends JpaRepository<SmartFillCampaign, UUID> {

    /** Duplicate-campaign protection at the application layer -- the unique index on the same column is the real guard. */
    boolean existsByCancelledBookingId(UUID cancelledBookingId);

    Optional<SmartFillCampaign> findByCancelledBookingId(UUID cancelledBookingId);

    /**
     * {@link SlotBookedSmartFillListener}'s lookup -- at most one active
     * (CREATED/SEARCHING/NOTIFYING) campaign can exist for a given slot at a
     * time in practice (a slot only becomes freed, hence campaign-eligible,
     * once more after its current campaign already resolved), but this
     * returns a list rather than assuming that invariant so a duplicate
     * never silently gets ignored.
     */
    List<SmartFillCampaign> findByAvailabilitySlotIdAndStatusIn(UUID availabilitySlotId,
            List<SmartFillCampaignStatus> statuses);

    /** {@link SmartFillCampaignJob}'s sweep target -- every campaign due for its next stage check. */
    List<SmartFillCampaign> findByStatusAndNextStageAtLessThanEqual(SmartFillCampaignStatus status, Instant cutoff);

    /** provider-insights' Smart Fill performance panel -- every campaign this provider has ever run. */
    List<SmartFillCampaign> findByProviderId(UUID providerId);
}
