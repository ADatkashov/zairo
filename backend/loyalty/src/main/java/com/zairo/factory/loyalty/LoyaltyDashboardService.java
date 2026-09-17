package com.zairo.factory.loyalty;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Business-admin overview metrics (Phase 11/17) -- every number here is a
 * cheap indexed aggregate query (see LoyaltyAccountRepository/
 * LoyaltyRedemptionRepository), never a full scan or an in-memory sum over
 * every transaction (Phase 23).
 */
@Service
public class LoyaltyDashboardService {

    private static final int ACTIVE_WINDOW_DAYS = 90;

    private final LoyaltyAccountRepository accountRepository;
    private final LoyaltyRedemptionRepository redemptionRepository;
    private final Clock clock;

    public LoyaltyDashboardService(LoyaltyAccountRepository accountRepository,
            LoyaltyRedemptionRepository redemptionRepository, Clock clock) {
        this.accountRepository = accountRepository;
        this.redemptionRepository = redemptionRepository;
        this.clock = clock;
    }

    public Overview getOverview(UUID providerId) {
        Instant activeSince = clock.instant().minus(ACTIVE_WINDOW_DAYS, ChronoUnit.DAYS);
        long members = accountRepository.countByProviderId(providerId);
        long activeMembers = accountRepository.countActiveSince(providerId, activeSince);
        long pointsIssued = accountRepository.sumLifetimeEarned(providerId);
        long pointsRedeemed = accountRepository.sumLifetimeRedeemed(providerId);
        long outstandingPoints = accountRepository.sumOutstandingBalance(providerId);
        long rewardsRedeemed = redemptionRepository.countByProviderIdAndStatus(providerId,
                LoyaltyRedemptionStatus.APPLIED)
                + redemptionRepository.countByProviderIdAndStatus(providerId, LoyaltyRedemptionStatus.ACTIVE);
        return new Overview(members, activeMembers, pointsIssued, pointsRedeemed, outstandingPoints, rewardsRedeemed);
    }

    public record Overview(long totalMembers, long activeMembers, long totalPointsIssued, long totalPointsRedeemed,
            long outstandingPointsLiability, long rewardsRedeemed) {
    }
}
