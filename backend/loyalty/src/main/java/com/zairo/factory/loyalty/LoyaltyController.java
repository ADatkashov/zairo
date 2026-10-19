package com.zairo.factory.loyalty;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.loyalty.LoyaltyDtos.CancelRedemptionRequest;
import com.zairo.factory.loyalty.LoyaltyDtos.LoyaltyBusinessDetailResponse;
import com.zairo.factory.loyalty.LoyaltyDtos.LoyaltyBusinessSummaryResponse;
import com.zairo.factory.loyalty.LoyaltyDtos.LoyaltyRedemptionResponse;
import com.zairo.factory.loyalty.LoyaltyDtos.LoyaltyRewardResponse;
import com.zairo.factory.loyalty.LoyaltyDtos.LoyaltyTransactionResponse;
import com.zairo.factory.loyalty.LoyaltyDtos.NextMilestoneResponse;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Every customer-facing Loyalty endpoint -- "my rewards" across every
 * business, one business's own loyalty page, its reward catalog, this
 * customer's own history/redemptions. Always scoped to the caller's own
 * identity (see {@link CurrentUser}) -- there is no "view another
 * customer's loyalty" endpoint here; that's {@code LoyaltyAdminController}'s
 * job, gated by {@code ProviderOwnership}.
 */
@RestController
@Tag(name = "Loyalty")
public class LoyaltyController {

    private static final int EXPIRING_SOON_DAYS = 30;

    private final LoyaltyProgramService programService;
    private final LoyaltyLedgerService ledgerService;
    private final LoyaltyRewardService rewardService;
    private final LoyaltyRedemptionService redemptionService;
    private final LoyaltyAccountRepository accountRepository;
    private final LoyaltyEarnLotRepository earnLotRepository;
    private final LoyaltyTransactionRepository transactionRepository;
    private final LoyaltyMilestoneRuleRepository milestoneRuleRepository;
    private final LoyaltyTierRuleRepository tierRuleRepository;
    private final ProviderRepository providerRepository;

    public LoyaltyController(LoyaltyProgramService programService, LoyaltyLedgerService ledgerService,
            LoyaltyRewardService rewardService, LoyaltyRedemptionService redemptionService,
            LoyaltyAccountRepository accountRepository, LoyaltyEarnLotRepository earnLotRepository,
            LoyaltyTransactionRepository transactionRepository,
            LoyaltyMilestoneRuleRepository milestoneRuleRepository, LoyaltyTierRuleRepository tierRuleRepository,
            ProviderRepository providerRepository) {
        this.programService = programService;
        this.ledgerService = ledgerService;
        this.rewardService = rewardService;
        this.redemptionService = redemptionService;
        this.accountRepository = accountRepository;
        this.earnLotRepository = earnLotRepository;
        this.transactionRepository = transactionRepository;
        this.milestoneRuleRepository = milestoneRuleRepository;
        this.tierRuleRepository = tierRuleRepository;
        this.providerRepository = providerRepository;
    }

    @Operation(summary = "My rewards across every business", description = """
            One row per business the caller has ever earned or held loyalty points with -- each business's \
            balance, tier, and expiring-soon points are entirely independent of every other (see this \
            module's own package-info: loyalty is never pooled across businesses).""")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/loyalty")
    public List<LoyaltyBusinessSummaryResponse> myLoyalty() {
        UUID userId = CurrentUser.requireUserId();
        Instant expiringCutoff = Instant.now().plus(EXPIRING_SOON_DAYS, ChronoUnit.DAYS);
        return accountRepository.findByUserId(userId).stream().map(account -> {
            String providerName = providerRepository.findById(account.getProviderId()).map(Provider::getName)
                    .orElse(null);
            LoyaltyProgram program = programService.findByProviderId(account.getProviderId()).orElse(null);
            String tierName = currentTierName(account);
            int expiringSoon = earnLotRepository.sumExpiringBy(account.getProviderId(), account.getUserId(),
                    expiringCutoff);
            return new LoyaltyBusinessSummaryResponse(account.getProviderId(), providerName,
                    program != null && program.isEnabled(), account.getPointsBalance(), account.getLifetimeEarned(),
                    tierName, expiringSoon);
        }).toList();
    }

    @Operation(summary = "This business's loyalty program, from the customer's point of view", description = """
            Works even for a business the caller has never booked with (an all-zero, no-program-configured \
            response) -- browsing this page never creates an account row by itself; one is only ever \
            created the first time points are actually earned or redeemed.""")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/loyalty/businesses/{providerId}")
    public LoyaltyBusinessDetailResponse businessLoyalty(@PathVariable UUID providerId) {
        UUID userId = CurrentUser.requireUserId();
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        LoyaltyProgram program = programService.findByProviderId(providerId).orElse(null);
        LoyaltyAccount account = ledgerService.findAccount(providerId, userId)
                .orElseGet(() -> new LoyaltyAccount(UUID.randomUUID(), providerId, userId, Instant.now()));

        List<LoyaltyMilestoneRule> milestones = program == null ? List.of()
                : milestoneRuleRepository.findByProgramIdOrderByVisitsRequiredAsc(program.getId());
        NextMilestoneResponse nextMilestone = milestones.stream()
                .filter(m -> m.getVisitsRequired() > account.getCompletedVisits()).findFirst()
                .map(m -> new NextMilestoneResponse(
                        m.getLabel() != null ? m.getLabel() : m.getVisitsRequired() + " visits", m.getVisitsRequired(),
                        m.getVisitsRequired() - account.getCompletedVisits(), m.getPointsAwarded()))
                .orElse(null);

        int expiringSoon = earnLotRepository.sumExpiringBy(providerId, userId,
                Instant.now().plus(EXPIRING_SOON_DAYS, ChronoUnit.DAYS));
        int availableRewards = program != null && program.isEnabled() ? rewardService.listRedeemable(providerId).size()
                : 0;

        return LoyaltyBusinessDetailResponse.of(provider.getName(), program, account, currentTierName(account),
                expiringSoon, nextMilestone, availableRewards);
    }

    @Operation(summary = "This business's redeemable rewards", description =
            "Empty if the business has no enabled loyalty program, or none of its rewards are currently active.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/loyalty/businesses/{providerId}/rewards")
    public List<LoyaltyRewardResponse> rewards(@PathVariable UUID providerId) {
        UUID userId = CurrentUser.requireUserId();
        LoyaltyProgram program = programService.findByProviderId(providerId).orElse(null);
        if (program == null || !program.isEnabled()) {
            return List.of();
        }
        int balance = ledgerService.findAccount(providerId, userId).map(LoyaltyAccount::getPointsBalance).orElse(0);
        return rewardService.listRedeemable(providerId).stream().map(r -> LoyaltyRewardResponse.of(r, balance))
                .toList();
    }

    @Operation(summary = "This customer's own points history with one business", description =
            "Every EARNED/BONUS/REDEEMED/EXPIRED/REFUND/ADJUSTMENT/REVERSAL row, newest first -- the immutable ledger, unfiltered.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/loyalty/businesses/{providerId}/history")
    public Page<LoyaltyTransactionResponse> history(@PathVariable UUID providerId, Pageable pageable) {
        UUID userId = CurrentUser.requireUserId();
        return transactionRepository.findByProviderIdAndUserIdOrderByCreatedAtDesc(providerId, userId, pageable)
                .map(LoyaltyTransactionResponse::from);
    }

    @Operation(summary = "Redeem a reward", description = """
            Spends points on one reward and issues a redemption code -- see LoyaltyRedemptionService for every \
            validation this runs (program enabled, reward currently redeemable, sufficient/minimum balance) \
            and its concurrency guarantees against a double-spend.""")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/loyalty/rewards/{rewardId}/redeem")
    @ResponseStatus(HttpStatus.CREATED)
    public LoyaltyRedemptionResponse redeem(@Parameter(description = "The reward to redeem.") @PathVariable
            UUID rewardId) {
        UUID userId = CurrentUser.requireUserId();
        LoyaltyRedemption redemption = redemptionService.redeem(userId, rewardId);
        return toResponse(redemption);
    }

    @Operation(summary = "This customer's own redemptions across every business", description =
            "Active codes, applied history, and cancelled/expired ones -- newest first.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/loyalty/redemptions")
    public Page<LoyaltyRedemptionResponse> myRedemptions(Pageable pageable) {
        UUID userId = CurrentUser.requireUserId();
        return redemptionService.findByCustomer(userId, pageable).map(this::toResponse);
    }

    @Operation(summary = "One of this customer's own redemptions", description = "404 if it isn't the caller's own.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/loyalty/redemptions/{id}")
    public LoyaltyRedemptionResponse myRedemption(@PathVariable UUID id) {
        UUID userId = CurrentUser.requireUserId();
        return toResponse(redemptionService.getOwnedByCustomer(id, userId));
    }

    @Operation(summary = "Cancel one of this customer's own unused redemptions", description = """
            Only while it's still ACTIVE (unapplied) -- refunds the spent points immediately as a REFUND \
            ledger entry. A redemption a business has already applied to a booking can no longer be cancelled.""")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/loyalty/redemptions/{id}/cancel")
    public LoyaltyRedemptionResponse cancelMyRedemption(@PathVariable UUID id,
            @RequestBody(required = false) CancelRedemptionRequest request) {
        UUID userId = CurrentUser.requireUserId();
        String reason = request == null ? null : request.reason();
        return toResponse(redemptionService.cancelAsCustomer(id, userId, reason));
    }

    private String currentTierName(LoyaltyAccount account) {
        LoyaltyProgram program = programService.findByProviderId(account.getProviderId()).orElse(null);
        if (program == null) {
            return null;
        }
        List<LoyaltyTierRule> tiers = tierRuleRepository.findByProgramIdOrderByMinLifetimePointsAsc(program.getId());
        LoyaltyTierRule tier = LoyaltyProgramService.currentTier(tiers, account.getLifetimeEarned());
        return tier == null ? null : tier.getName();
    }

    private LoyaltyRedemptionResponse toResponse(LoyaltyRedemption redemption) {
        Optional<Provider> provider = providerRepository.findById(redemption.getProviderId());
        return LoyaltyRedemptionResponse.of(redemption, provider.map(Provider::getName).orElse(null));
    }
}
