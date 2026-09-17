package com.zairo.factory.smartfill;

import com.zairo.factory.smartfill.SmartFillDtos.CampaignSummary;
import com.zairo.factory.smartfill.SmartFillDtos.SmartFillPerformanceResponse;
import java.math.BigDecimal;
import java.time.Instant;
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
        return performance(campaignRepository.findByProviderId(providerId));
    }

    /**
     * The same performance snapshot, scoped to one reporting period -- the
     * Business Analytics dashboard's "recovered N slots this month" tile,
     * which must move with the same date range as every other metric on
     * the page (see {@code providerinsights.BusinessAnalyticsService}).
     */
    public SmartFillPerformanceResponse performance(UUID providerId, Instant from, Instant to) {
        return performance(campaignRepository.findByProviderIdAndCreatedAtBetween(providerId, from, to));
    }

    /**
     * Every campaign of this provider's still actively trying to recover a
     * slot (not yet {@code BOOKED}/{@code EXPIRED}/{@code CANCELLED}) --
     * the Action Center's "Smart Fill opportunity" drill-down (see {@code
     * providerinsights.BusinessAnalyticsService#actions}), oldest slot
     * first so the most time-sensitive campaign surfaces first. Not
     * date-scoped, same "current state, not a historical report" reasoning
     * as the Action Center itself.
     */
    public List<CampaignSummary> activeCampaigns(UUID providerId) {
        List<SmartFillCampaign> active = campaignRepository.findByProviderId(providerId).stream()
                .filter(c -> c.getStatus() == SmartFillCampaignStatus.CREATED
                        || c.getStatus() == SmartFillCampaignStatus.SEARCHING
                        || c.getStatus() == SmartFillCampaignStatus.NOTIFYING)
                .sorted(Comparator.comparing(SmartFillCampaign::getSlotStartsAt))
                .toList();
        Map<UUID, List<CandidateOffer>> offersByCampaignId = active.stream()
                .collect(Collectors.toMap(SmartFillCampaign::getId,
                        campaign -> offerRepository.findByCampaignId(campaign.getId())));
        return active.stream().map(campaign -> toSummary(campaign, offersByCampaignId)).toList();
    }

    private SmartFillPerformanceResponse performance(List<SmartFillCampaign> campaigns) {
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
                .map(campaign -> toSummary(campaign, offersByCampaignId))
                .toList();

        return new SmartFillPerformanceResponse(slotsFreed, campaignsCreated, candidatesNotified, offersViewed,
                slotsRecovered, recoveryRate, recoveredRevenue, currency, recentCampaigns);
    }

    private static CampaignSummary toSummary(SmartFillCampaign campaign,
            Map<UUID, List<CandidateOffer>> offersByCampaignId) {
        int candidatesNotified = (int) offersByCampaignId.getOrDefault(campaign.getId(), List.of()).stream()
                .filter(o -> o.getNotifiedAt() != null).count();
        return new CampaignSummary(campaign.getId(), campaign.getStatus(), campaign.getSlotStartsAt(),
                candidatesNotified, campaign.getRecoveredBookingId());
    }
}
