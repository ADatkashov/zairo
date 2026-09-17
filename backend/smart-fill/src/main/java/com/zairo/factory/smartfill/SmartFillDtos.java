package com.zairo.factory.smartfill;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class SmartFillDtos {

    private SmartFillDtos() {
    }

    public record CandidateOfferResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            @Schema(example = "2026-09-01T15:00:00Z") Instant slotStartsAt,
            @Schema(example = "2026-09-01T15:30:00Z") Instant slotEndsAt,
            CandidateOfferStatus status,
            @Schema(example = "2026-09-01T12:00:00Z") Instant notifiedAt) {

        static CandidateOfferResponse from(CandidateOffer offer, SmartFillCampaign campaign) {
            return new CandidateOfferResponse(offer.getId(), campaign.getProviderId(), campaign.getServiceId(),
                    campaign.getAvailabilitySlotId(), campaign.getSlotStartsAt(), campaign.getSlotEndsAt(),
                    offer.getStatus(), offer.getNotifiedAt());
        }
    }

    public record UpdateSmartFillPreferenceRequest(@Schema(example = "true") boolean optedOut) {
    }

    public record SmartFillPreferenceResponse(@Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            boolean optedOut) {

        static SmartFillPreferenceResponse from(SmartFillUserPreference preference) {
            return new SmartFillPreferenceResponse(preference.getUserId(), preference.isOptedOut());
        }
    }

    /**
     * A business's Smart Fill ROI, for {@code provider-insights}'
     * dashboard -- see {@link SmartFillAnalyticsService#performance}.
     */
    public record SmartFillPerformanceResponse(
            long slotsFreed,
            long campaignsCreated,
            long candidatesNotified,
            long offersViewed,
            long slotsRecovered,
            double recoveryRate,
            BigDecimal recoveredRevenue,
            String currency,
            List<CampaignSummary> recentCampaigns) {
    }

    public record CampaignSummary(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID campaignId,
            SmartFillCampaignStatus status,
            @Schema(example = "2026-09-01T15:00:00Z") Instant slotStartsAt,
            int candidatesNotified,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID recoveredBookingId) {
    }
}
