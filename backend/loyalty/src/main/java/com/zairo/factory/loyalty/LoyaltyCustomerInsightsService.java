package com.zairo.factory.loyalty;

import com.zairo.factory.customerintelligence.CustomerIntelligenceService;
import com.zairo.factory.customerintelligence.CustomerProviderProfile;
import com.zairo.factory.customerintelligence.RetentionStatus;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

/**
 * Read-only composition of a customer's platform-wide behaviour ({@code
 * customer-intelligence}) with their loyalty standing (this module) --
 * Phase 14 of the feature brief. Never recomputes anything Customer
 * Intelligence already owns; only merges two already-cheap reads into one
 * response for the business-admin loyalty customer list. Same one-way
 * dependency direction as provider-insights/campaign-center (see this
 * module's own package-info) -- customer-intelligence has no idea this
 * class exists.
 */
@Service
public class LoyaltyCustomerInsightsService {

    private static final int EXPIRING_SOON_DAYS = 30;

    private final LoyaltyAccountRepository accountRepository;
    private final LoyaltyEarnLotRepository earnLotRepository;
    private final CustomerIntelligenceService customerIntelligenceService;
    private final Clock clock;

    public LoyaltyCustomerInsightsService(LoyaltyAccountRepository accountRepository,
            LoyaltyEarnLotRepository earnLotRepository, CustomerIntelligenceService customerIntelligenceService,
            Clock clock) {
        this.accountRepository = accountRepository;
        this.earnLotRepository = earnLotRepository;
        this.customerIntelligenceService = customerIntelligenceService;
        this.clock = clock;
    }

    public Page<CustomerLoyaltyInsight> listForBusiness(UUID providerId, Pageable pageable) {
        Page<LoyaltyAccount> accounts = accountRepository.findByProviderId(providerId, pageable);
        List<UUID> userIds = accounts.map(LoyaltyAccount::getUserId).toList();
        Map<UUID, CustomerProviderProfile> profiles = customerIntelligenceService.findProviderProfiles(providerId,
                userIds);
        Instant expiringCutoff = clock.instant().plus(EXPIRING_SOON_DAYS, ChronoUnit.DAYS);
        return accounts.map(account -> toInsight(account, profiles.get(account.getUserId()), expiringCutoff));
    }

    public CustomerLoyaltyInsight getForCustomer(UUID providerId, UUID userId) {
        LoyaltyAccount account = accountRepository.findByProviderIdAndUserId(providerId, userId)
                .orElseGet(() -> new LoyaltyAccount(UUID.randomUUID(), providerId, userId, clock.instant()));
        CustomerProviderProfile profile = customerIntelligenceService.getOrCalculateProviderProfile(userId,
                providerId);
        return toInsight(account, profile, clock.instant().plus(EXPIRING_SOON_DAYS, ChronoUnit.DAYS));
    }

    private CustomerLoyaltyInsight toInsight(LoyaltyAccount account, CustomerProviderProfile profile,
            Instant expiringCutoff) {
        int expiringSoon = earnLotRepository.sumExpiringBy(account.getProviderId(), account.getUserId(),
                expiringCutoff);
        return new CustomerLoyaltyInsight(account.getUserId(), account.getPointsBalance(),
                account.getLifetimeEarned(), account.getLifetimeRedeemed(), account.getCompletedVisits(),
                account.getLastActivityAt(), expiringSoon, profile == null ? null : profile.getRetentionStatus());
    }

    public record CustomerLoyaltyInsight(UUID userId, int pointsBalance, int lifetimeEarned, int lifetimeRedeemed,
            int completedVisits, Instant lastActivityAt, int pointsExpiringSoon, RetentionStatus retentionStatus) {
    }
}
