package com.zairo.factory.loyalty;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Owner-only CRUD over a business's own {@link LoyaltyProgram}/{@link
 * LoyaltyMilestoneRule}s -- see {@link LoyaltyController} for the
 * customer-facing read side, which only ever sees an enabled program.
 */
@Service
public class LoyaltyProgramService {

    private final LoyaltyProgramRepository programRepository;
    private final LoyaltyMilestoneRuleRepository milestoneRuleRepository;
    private final LoyaltyTierRuleRepository tierRuleRepository;
    private final Clock clock;

    public LoyaltyProgramService(LoyaltyProgramRepository programRepository,
            LoyaltyMilestoneRuleRepository milestoneRuleRepository, LoyaltyTierRuleRepository tierRuleRepository,
            Clock clock) {
        this.programRepository = programRepository;
        this.milestoneRuleRepository = milestoneRuleRepository;
        this.tierRuleRepository = tierRuleRepository;
        this.clock = clock;
    }

    /** Read-only helper for other services -- empty if the business has never configured loyalty at all. */
    public Optional<LoyaltyProgram> findByProviderId(UUID providerId) {
        return programRepository.findByProviderId(providerId);
    }

    /** The program's settings, creating a disabled draft with sane defaults on first access -- never null. */
    @Transactional
    public LoyaltyProgram getOrCreateDraft(UUID providerId, String defaultName) {
        return programRepository.findByProviderId(providerId)
                .orElseGet(() -> programRepository.save(new LoyaltyProgram(UUID.randomUUID(), providerId,
                        defaultName, clock.instant())));
    }

    @Transactional
    public LoyaltyProgram updateSettings(UUID providerId, boolean enabled, String name, String description,
            int fixedPointsPerBooking, BigDecimal pointsPerCurrencyUnit, int firstBookingBonusPoints,
            int repeatVisitBonusPoints, int repeatVisitThreshold, int reviewBonusPoints,
            BigDecimal pointsPerCurrencyUnitRedemption, Integer minRedemptionPoints,
            Integer maxRedemptionPointsPerBooking, boolean pointsExpireEnabled, Integer pointsExpirationMonths,
            Integer dailyEarningPointsCap, Integer monthlyEarningPointsCap) {
        if (name == null || name.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Program name must not be blank");
        }
        if (fixedPointsPerBooking < 0 || firstBookingBonusPoints < 0 || repeatVisitBonusPoints < 0
                || reviewBonusPoints < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Earning amounts must not be negative");
        }
        if (repeatVisitThreshold < 2) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "repeatVisitThreshold must be at least 2 (the first visit can't also be a repeat visit)");
        }
        if (pointsPerCurrencyUnit != null && pointsPerCurrencyUnit.signum() < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "pointsPerCurrencyUnit must not be negative");
        }
        if (pointsExpireEnabled && (pointsExpirationMonths == null || pointsExpirationMonths <= 0)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "pointsExpirationMonths must be a positive number when expiration is enabled");
        }

        LoyaltyProgram program = getOrCreateDraft(providerId, name);
        program.applySettings(enabled, name, description, fixedPointsPerBooking,
                pointsPerCurrencyUnit == null ? BigDecimal.ZERO : pointsPerCurrencyUnit, firstBookingBonusPoints,
                repeatVisitBonusPoints, repeatVisitThreshold, reviewBonusPoints, pointsPerCurrencyUnitRedemption,
                minRedemptionPoints, maxRedemptionPointsPerBooking, pointsExpireEnabled, pointsExpirationMonths,
                dailyEarningPointsCap, monthlyEarningPointsCap, clock.instant());
        return programRepository.save(program);
    }

    public List<LoyaltyMilestoneRule> getMilestones(UUID providerId) {
        LoyaltyProgram program = getOrCreateDraft(providerId, "Loyalty Rewards");
        return milestoneRuleRepository.findByProgramIdOrderByVisitsRequiredAsc(program.getId());
    }

    /** Replaces the whole milestone ladder in one call -- simplest correct shape for a small, fully-owned config list. */
    @Transactional
    public List<LoyaltyMilestoneRule> replaceMilestones(UUID providerId, List<MilestoneInput> milestones) {
        LoyaltyProgram program = getOrCreateDraft(providerId, "Loyalty Rewards");
        for (MilestoneInput milestone : milestones) {
            if (milestone.visitsRequired() < 1) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "visitsRequired must be at least 1");
            }
            if (milestone.pointsAwarded() < 1) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "pointsAwarded must be at least 1");
            }
        }
        milestoneRuleRepository.deleteByProgramId(program.getId());
        milestoneRuleRepository.flush();
        List<LoyaltyMilestoneRule> saved = milestones.stream()
                .map(m -> new LoyaltyMilestoneRule(UUID.randomUUID(), program.getId(), m.visitsRequired(),
                        m.pointsAwarded(), m.label()))
                .toList();
        return milestoneRuleRepository.saveAll(saved);
    }

    public record MilestoneInput(int visitsRequired, int pointsAwarded, String label) {
    }

    public List<LoyaltyTierRule> getTiers(UUID providerId) {
        LoyaltyProgram program = getOrCreateDraft(providerId, "Loyalty Rewards");
        return tierRuleRepository.findByProgramIdOrderByMinLifetimePointsAsc(program.getId());
    }

    /** Replaces the whole tier ladder in one call -- same "small, fully-owned config list" shape as milestones. */
    @Transactional
    public List<LoyaltyTierRule> replaceTiers(UUID providerId, List<TierInput> tiers) {
        LoyaltyProgram program = getOrCreateDraft(providerId, "Loyalty Rewards");
        for (TierInput tier : tiers) {
            if (tier.name() == null || tier.name().isBlank()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Tier name must not be blank");
            }
            if (tier.minLifetimePoints() < 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "minLifetimePoints must not be negative");
            }
        }
        tierRuleRepository.deleteByProgramId(program.getId());
        tierRuleRepository.flush();
        List<LoyaltyTierRule> saved = tiers.stream()
                .map(t -> new LoyaltyTierRule(UUID.randomUUID(), program.getId(), t.name(), t.minLifetimePoints()))
                .toList();
        return tierRuleRepository.saveAll(saved);
    }

    public record TierInput(String name, int minLifetimePoints) {
    }

    /**
     * The highest tier whose threshold a customer's lifetime earned points
     * meet or exceed -- null if the business hasn't configured any tiers,
     * or the customer hasn't reached the lowest one yet. Deliberately a
     * pure function over already-loaded data, not a query -- see this
     * class's own doc comment on {@link LoyaltyTierRule}.
     */
    public static LoyaltyTierRule currentTier(List<LoyaltyTierRule> tiersAscending, int lifetimeEarned) {
        LoyaltyTierRule current = null;
        for (LoyaltyTierRule tier : tiersAscending) {
            if (tier.getMinLifetimePoints() <= lifetimeEarned) {
                current = tier;
            } else {
                break;
            }
        }
        return current;
    }
}
