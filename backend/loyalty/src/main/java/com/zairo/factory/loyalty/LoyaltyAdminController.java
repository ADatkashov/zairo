package com.zairo.factory.loyalty;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.AdjustPointsRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.ApplyRedemptionRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.CancelRedemptionRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.CustomerInsightResponse;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.MilestoneResponse;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.OverviewResponse;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.RedemptionAdminResponse;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.ReplaceMilestonesRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.ReplaceTiersRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.RewardRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.RewardResponse;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.TierResponse;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.UpdateLoyaltySettingsRequest;
import com.zairo.factory.loyalty.LoyaltyCustomerInsightsService.CustomerLoyaltyInsight;
import com.zairo.factory.providers.OwnsProvider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Every business-admin Loyalty endpoint -- settings, milestones, tiers,
 * the reward catalog, the customer roster, manual adjustments, and the
 * dashboard overview. Every method starts with {@link
 * ProviderOwnership#requireOwner} -- the same 404-vs-403 ownership check
 * every other owner-only surface in this codebase uses.
 */
@RestController
@Tag(name = "Business Admin: Loyalty")
public class LoyaltyAdminController {

    private final LoyaltyProgramService programService;
    private final LoyaltyRewardService rewardService;
    private final LoyaltyRedemptionService redemptionService;
    private final LoyaltyLedgerService ledgerService;
    private final LoyaltyDashboardService dashboardService;
    private final LoyaltyCustomerInsightsService customerInsightsService;
    private final ProviderOwnership providerOwnership;
    private final UserRepository userRepository;
    private final LoyaltyBirthdayService birthdayService;
    private final LoyaltyGreetingService greetingService;

    public LoyaltyAdminController(LoyaltyProgramService programService, LoyaltyRewardService rewardService,
            LoyaltyRedemptionService redemptionService, LoyaltyLedgerService ledgerService,
            LoyaltyDashboardService dashboardService, LoyaltyCustomerInsightsService customerInsightsService,
            ProviderOwnership providerOwnership, UserRepository userRepository,
            LoyaltyBirthdayService birthdayService, LoyaltyGreetingService greetingService) {
        this.programService = programService;
        this.rewardService = rewardService;
        this.redemptionService = redemptionService;
        this.ledgerService = ledgerService;
        this.dashboardService = dashboardService;
        this.customerInsightsService = customerInsightsService;
        this.providerOwnership = providerOwnership;
        this.userRepository = userRepository;
        this.birthdayService = birthdayService;
        this.greetingService = greetingService;
    }

    // ---- Settings ----

    @Operation(summary = "This business's loyalty settings", description =
            "Auto-creates a disabled draft with sane defaults on first access -- never 404s for an owned business.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/settings")
    @OwnsProvider
    public LoyaltyAdminDtos.LoyaltySettingsResponse getSettings(@PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        return LoyaltyAdminDtos.LoyaltySettingsResponse.from(programService.getOrCreateDraft(providerId,
                "Loyalty Rewards"));
    }

    @Operation(summary = "Update this business's loyalty settings", description =
            "Full replace of every earning/redemption/expiration rule in one call -- see LoyaltyProgramService for validation.")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/business/{providerId}/loyalty/settings")
    @OwnsProvider
    public LoyaltyAdminDtos.LoyaltySettingsResponse updateSettings(@PathVariable UUID providerId,
            @RequestBody UpdateLoyaltySettingsRequest request, HttpServletRequest httpRequest) {
        LoyaltyProgram program = programService.updateSettings(providerId, request.enabled(), request.name(),
                request.description(), request.fixedPointsPerBooking(), request.pointsPerCurrencyUnit(),
                request.firstBookingBonusPoints(), request.repeatVisitBonusPoints(), request.repeatVisitThreshold(),
                request.reviewBonusPoints(), request.pointsPerCurrencyUnitRedemption(), request.minRedemptionPoints(),
                request.maxRedemptionPointsPerBooking(), request.pointsExpireEnabled(),
                request.pointsExpirationMonths(), request.dailyEarningPointsCap(), request.monthlyEarningPointsCap(),
                request.birthdayBonusPoints());
        return LoyaltyAdminDtos.LoyaltySettingsResponse.from(program);
    }

    @Operation(summary = "This business's milestone ladder")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/milestones")
    @OwnsProvider
    public List<MilestoneResponse> getMilestones(@PathVariable UUID providerId, HttpServletRequest httpRequest) {
        return programService.getMilestones(providerId).stream().map(MilestoneResponse::from).toList();
    }

    @Operation(summary = "Replace this business's milestone ladder", description =
            "Full replace, not a partial patch -- send every milestone the business wants, including unchanged ones.")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/business/{providerId}/loyalty/milestones")
    @OwnsProvider
    public List<MilestoneResponse> replaceMilestones(@PathVariable UUID providerId,
            @RequestBody ReplaceMilestonesRequest request, HttpServletRequest httpRequest) {
        List<LoyaltyProgramService.MilestoneInput> inputs = request.milestones().stream()
                .map(m -> new LoyaltyProgramService.MilestoneInput(m.visitsRequired(), m.pointsAwarded(), m.label()))
                .toList();
        return programService.replaceMilestones(providerId, inputs).stream().map(MilestoneResponse::from).toList();
    }

    @Operation(summary = "This business's loyalty tier ladder")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/tiers")
    @OwnsProvider
    public List<TierResponse> getTiers(@PathVariable UUID providerId, HttpServletRequest httpRequest) {
        return programService.getTiers(providerId).stream().map(TierResponse::from).toList();
    }

    @Operation(summary = "Replace this business's tier ladder", description = "Full replace, same shape as milestones.")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/business/{providerId}/loyalty/tiers")
    @OwnsProvider
    public List<TierResponse> replaceTiers(@PathVariable UUID providerId, @RequestBody ReplaceTiersRequest request,
            HttpServletRequest httpRequest) {
        List<LoyaltyProgramService.TierInput> inputs = request.tiers().stream()
                .map(t -> new LoyaltyProgramService.TierInput(t.name(), t.minLifetimePoints())).toList();
        return programService.replaceTiers(providerId, inputs).stream().map(TierResponse::from).toList();
    }

    // ---- Dashboard ----

    @Operation(summary = "Loyalty dashboard overview", description =
            "Members, points issued/redeemed, outstanding liability, rewards redeemed -- every number a cheap aggregate query.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/overview")
    @OwnsProvider
    public OverviewResponse getOverview(@PathVariable UUID providerId, HttpServletRequest httpRequest) {
        return OverviewResponse.from(dashboardService.getOverview(providerId));
    }

    // ---- Birthdays ----

    @Operation(summary = "Members with a birthday coming up", description =
            "Members who opted in to greetings and gave a birth date, soonest first (today included). Month/day only "
                    + "-- never the birth year. bonusPoints is what the program grants on the birthday (0 = none); "
                    + "bonusAwarded is true once today's bonus was granted.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/birthdays")
    @OwnsProvider
    public List<LoyaltyAdminDtos.BirthdayResponse> getBirthdays(@PathVariable UUID providerId,
            @RequestParam(defaultValue = "30") int days, HttpServletRequest httpRequest) {
        int window = Math.max(0, Math.min(days, 366));
        LoyaltyProgram program = programService.getOrCreateDraft(providerId, "Loyalty Rewards");
        int bonus = program.isEnabled() ? program.getBirthdayBonusPoints() : 0;
        return birthdayService.upcoming(providerId, window).stream()
                .map(b -> new LoyaltyAdminDtos.BirthdayResponse(b.userId(), b.displayName(),
                        b.date().getMonthValue(), b.date().getDayOfMonth(), b.daysUntil(), bonus, b.bonusAwarded(),
                        b.greetedToday()))
                .toList();
    }

    @Operation(summary = "Greet a member by hand, optionally with bonus points", description = """
            Sends the member an in-app notification (and an email if they have one) with an optional personal \
            message, and optionally credits up to 1000 bonus points (recorded as an auditable ADJUSTMENT naming \
            the acting owner). Only members who agreed to greetings can be greeted: 409 otherwise, 409 if they \
            were already greeted today, and 409 if points are requested while the program is off.""")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/business/{providerId}/loyalty/customers/{userId}/greet")
    @ResponseStatus(HttpStatus.CREATED)
    @OwnsProvider
    public LoyaltyAdminDtos.GreetingResponse greet(@PathVariable UUID providerId, @PathVariable UUID userId,
            @RequestBody LoyaltyAdminDtos.SendGreetingRequest request, HttpServletRequest httpRequest) {
        UUID ownerId = CurrentUser.requireUserId(httpRequest);
        LoyaltyGreeting greeting = greetingService.send(providerId, userId, ownerId, request.message(),
                request.bonusPoints() == null ? 0 : request.bonusPoints());
        return new LoyaltyAdminDtos.GreetingResponse(greeting.getId(), greeting.getBonusPoints(),
                greeting.getCreatedAt());
    }

    // ---- Customers ----

    @Operation(summary = "This business's loyalty members", description =
            "Balance, lifetime earned/redeemed, visits, retention status (composed read-through to Customer Intelligence), expiring-soon points.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/customers")
    @OwnsProvider
    public Page<CustomerInsightResponse> getCustomers(@PathVariable UUID providerId, Pageable pageable,
            HttpServletRequest httpRequest) {
        Page<CustomerLoyaltyInsight> insights = customerInsightsService.listForBusiness(providerId, pageable);
        Map<UUID, User> users = userRepository
                .findAllById(insights.map(CustomerLoyaltyInsight::userId).toList()).stream()
                .collect(Collectors.toMap(User::getId, u -> u));
        return insights.map(insight -> toResponse(insight, users.get(insight.userId())));
    }

    @Operation(summary = "One customer's loyalty profile with this business")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/customers/{userId}")
    @OwnsProvider
    public CustomerInsightResponse getCustomer(@PathVariable UUID providerId, @PathVariable UUID userId,
            HttpServletRequest httpRequest) {
        CustomerLoyaltyInsight insight = customerInsightsService.getForCustomer(providerId, userId);
        return toResponse(insight, userRepository.findById(userId).orElse(null));
    }

    @Operation(summary = "Manually adjust a customer's points balance", description = """
            Authorized correction only -- always requires a non-blank reason, and is itself recorded as an \
            auditable ADJUSTMENT ledger entry naming the acting business owner (Phase 20). Positive delta \
            credits points; negative debits them (rejected with 409 if it would take the balance negative).""")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/business/{providerId}/loyalty/customers/{userId}/adjust")
    @OwnsProvider
    public LoyaltyDtos.LoyaltyTransactionResponse adjustPoints(@PathVariable UUID providerId,
            @PathVariable UUID userId, @RequestBody AdjustPointsRequest request, HttpServletRequest httpRequest) {
        UUID actorId = CurrentUser.requireUserId(httpRequest);
        LoyaltyProgram program = programService.findByProviderId(providerId).orElse(null);
        LoyaltyTransaction tx = ledgerService.adjust(providerId, userId, request.delta(), request.reason(), actorId,
                program);
        return LoyaltyDtos.LoyaltyTransactionResponse.from(tx);
    }

    // ---- Rewards ----

    @Operation(summary = "Every reward this business has ever created", description = "Includes inactive/expired ones -- see the customer-facing endpoint for the redeemable-now subset.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/rewards")
    @OwnsProvider
    public List<RewardResponse> listRewards(@PathVariable UUID providerId, HttpServletRequest httpRequest) {
        return rewardService.listAll(providerId).stream().map(RewardResponse::from).toList();
    }

    @Operation(summary = "Create a reward")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/business/{providerId}/loyalty/rewards")
    @ResponseStatus(HttpStatus.CREATED)
    @OwnsProvider
    public RewardResponse createReward(@PathVariable UUID providerId, @RequestBody RewardRequest request,
            HttpServletRequest httpRequest) {
        LoyaltyReward reward = rewardService.create(providerId, request.name(), request.description(),
                request.type(), request.pointsCost(), request.discountAmount(), request.discountCurrency(),
                request.discountPercentage(), request.serviceId(), request.maxRedemptions(), request.startsAt(),
                request.endsAt(), request.terms());
        return RewardResponse.from(reward);
    }

    @Operation(summary = "Update a reward", description =
            "Edits only the catalog entry going forward -- already-issued redemptions keep their own snapshot of the reward as it was when redeemed.")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/business/{providerId}/loyalty/rewards/{rewardId}")
    @OwnsProvider
    public RewardResponse updateReward(@PathVariable UUID providerId, @PathVariable UUID rewardId,
            @RequestBody RewardRequest request, HttpServletRequest httpRequest) {
        LoyaltyReward reward = rewardService.update(providerId, rewardId, request.name(), request.description(),
                request.type(), request.pointsCost(), request.discountAmount(), request.discountCurrency(),
                request.discountPercentage(), request.serviceId(), request.maxRedemptions(), request.startsAt(),
                request.endsAt(), request.terms());
        return RewardResponse.from(reward);
    }

    @Operation(summary = "Activate a reward")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/business/{providerId}/loyalty/rewards/{rewardId}/activate")
    @OwnsProvider
    public RewardResponse activateReward(@PathVariable UUID providerId, @PathVariable UUID rewardId,
            HttpServletRequest httpRequest) {
        return RewardResponse.from(rewardService.setActive(providerId, rewardId, true));
    }

    @Operation(summary = "Deactivate a reward", description = "Existing active redemptions are unaffected -- this only stops new ones.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/business/{providerId}/loyalty/rewards/{rewardId}/deactivate")
    @OwnsProvider
    public RewardResponse deactivateReward(@PathVariable UUID providerId, @PathVariable UUID rewardId,
            HttpServletRequest httpRequest) {
        return RewardResponse.from(rewardService.setActive(providerId, rewardId, false));
    }

    @Operation(summary = "Delete a reward", description = "409 if it has ever been redeemed -- deactivate it instead of deleting real history.")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/business/{providerId}/loyalty/rewards/{rewardId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @OwnsProvider
    public void deleteReward(@PathVariable UUID providerId, @PathVariable UUID rewardId,
            HttpServletRequest httpRequest) {
        rewardService.delete(providerId, rewardId);
    }

    // ---- Redemptions ----

    @Operation(summary = "This business's redemption codes", description = "Every status -- active, applied, cancelled, expired -- newest first.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/loyalty/redemptions")
    @OwnsProvider
    public Page<RedemptionAdminResponse> listRedemptions(@PathVariable UUID providerId, Pageable pageable,
            HttpServletRequest httpRequest) {
        return redemptionService.findByBusiness(providerId, pageable).map(RedemptionAdminResponse::from);
    }

    @Operation(summary = "Apply a customer's redemption code to a booking (checkout)", description = """
            The business's own confirmation step at checkout/service time -- see LoyaltyRedemptionService for \
            every validation (code belongs to this business, still ACTIVE and unexpired, booking belongs to \
            the same customer and business, per-booking points cap).""")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/business/{providerId}/loyalty/redemptions/{code}/apply")
    @OwnsProvider
    public RedemptionAdminResponse applyRedemption(@PathVariable UUID providerId, @PathVariable String code,
            @RequestBody ApplyRedemptionRequest request, HttpServletRequest httpRequest) {
        return RedemptionAdminResponse.from(redemptionService.applyToBooking(providerId, code, request.bookingId()));
    }

    @Operation(summary = "Cancel a customer's active redemption code", description = "Refunds the spent points -- e.g. suspected abuse or a customer service correction.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/business/{providerId}/loyalty/redemptions/{id}/cancel")
    @OwnsProvider
    public RedemptionAdminResponse cancelRedemption(@PathVariable UUID providerId, @PathVariable UUID id,
            @RequestBody(required = false) CancelRedemptionRequest request, HttpServletRequest httpRequest) {
        String reason = request == null ? null : request.reason();
        return RedemptionAdminResponse.from(redemptionService.cancelAsBusiness(providerId, id, reason));
    }

    private CustomerInsightResponse toResponse(CustomerLoyaltyInsight insight, User user) {
        return new CustomerInsightResponse(insight.userId(), user == null ? null : user.getDisplayName(),
                user == null ? null : user.getEmail(), insight.pointsBalance(), insight.lifetimeEarned(),
                insight.lifetimeRedeemed(), insight.completedVisits(), insight.lastActivityAt(),
                insight.pointsExpiringSoon(), insight.retentionStatus() == null ? null
                        : insight.retentionStatus().name());
    }
}
