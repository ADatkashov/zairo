package com.zairo.factory.smartfill;

import com.zairo.factory.smartfill.SmartFillDtos.CampaignSummary;
import com.zairo.factory.smartfill.SmartFillDtos.SmartFillPerformanceResponse;
import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * The business-value number this whole module exists to produce: how many
 * cancelled bookings Smart Fill actually turned back into revenue for one
 * provider. Read-only, computed fresh on every call from {@link
 * SmartFillCampaign}/{@link CandidateOffer} rather than a separate
 * aggregates table -- same "fine at today's scale" discipline as {@code
 * providerinsights.ProviderInsightsService}. Exposed under {@code
 * provider-insights}' existing owner-facing dashboard controller rather
 * than a second admin surface (see that module's build.gradle.kts).
 *
 * <p>Revenue is never a guessed/flat number -- {@link
 * SmartFillCampaign#getPriceAmount()} is the real {@code
 * services.ServiceOffering} price captured at the moment each campaign was
 * created (see that field's own doc comment), summed only over campaigns
 * that actually reached BOOKED.
 */
@Service
public class SmartFillAnalyticsService {

    private static final int MAX_RECENT_CAMPAIGNS = 20;

    private final SmartFillCampaignRepository campaignRepository;
    private final CandidateOfferRepository offerRepository;

    public SmartFillAnalyticsService(SmartFillCampaignRepository campaignRepository,
            CandidateOfferRepository offerRepository) {
        this.campaignRepository = campaignRepository;
        this.offerRepository = offerRepository;
    }

    public SmartFillPerformanceResponse performance(UUID providerId) {
        List<SmartFillCampaign> campaigns = campaignRepository.findByProviderId(providerId);
        if (campaigns.isEmpty()) {
            return new SmartFillPerformanceResponse(0, 0, 0, 0, 0, 0.0, BigDecimal.ZERO, null, List.of());
        }

        List<CandidateOffer> offers = campaigns.stream()
                .flatMap(campaign -> offerRepository.findByCampaignId(campaign.getId()).stream())
                .toList();
        Map<UUID, List<CandidateOffer>> offersByCampaignId = offers.stream()
                .collect(Collectors.groupingBy(CandidateOffer::getCampaignId));

        long slotsFreed = campaigns.size();
        long campaignsCreated = campaigns.size();
        long candidatesNotified = offers.stream().filter(o -> o.getNotifiedAt() != null).count();
        long offersViewed = offers.stream()
                .filter(o -> o.getStatus() == CandidateOfferStatus.VIEWED || o.getStatus() == CandidateOfferStatus.ACCEPTED)
                .count();

        List<SmartFillCampaign> recovered = campaigns.stream()
                .filter(c -> c.getStatus() == SmartFillCampaignStatus.BOOKED).toList();
        long slotsRecovered = recovered.size();
        double recoveryRate = campaignsCreated == 0 ? 0.0 : (double) slotsRecovered / campaignsCreated;
        BigDecimal recoveredRevenue = recovered.stream().map(SmartFillCampaign::getPriceAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        String currency = recovered.isEmpty() ? null : recovered.get(0).getPriceCurrency();

        List<CampaignSummary> recentCampaigns = campaigns.stream()
                .sorted(Comparator.comparing(SmartFillCampaign::getCreatedAt).reversed())
                .limit(MAX_RECENT_CAMPAIGNS)
                .map(campaign -> new CampaignSummary(campaign.getId(), campaign.getStatus(),
                        campaign.getSlotStartsAt(),
                        (int) offersByCampaignId.getOrDefault(campaign.getId(), List.of()).stream()
                                .filter(o -> o.getNotifiedAt() != null).count(),
                        campaign.getRecoveredBookingId()))
                .toList();

        return new SmartFillPerformanceResponse(slotsFreed, campaignsCreated, candidatesNotified, offersViewed,
                slotsRecovered, recoveryRate, recoveredRevenue, currency, recentCampaigns);
    }
}
