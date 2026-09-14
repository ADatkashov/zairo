package com.zairo.factory.loyalty;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/** Owner-only CRUD over a business's own reward catalog -- see {@link LoyaltyReward}'s own doc comment. */
@Service
public class LoyaltyRewardService {

    private final LoyaltyRewardRepository rewardRepository;
    private final Clock clock;

    public LoyaltyRewardService(LoyaltyRewardRepository rewardRepository, Clock clock) {
        this.rewardRepository = rewardRepository;
        this.clock = clock;
    }

    public List<LoyaltyReward> listAll(UUID providerId) {
        return rewardRepository.findByProviderIdOrderByPointsCostAsc(providerId);
    }

    public List<LoyaltyReward> listRedeemable(UUID providerId) {
        return rewardRepository.findRedeemableNow(providerId, clock.instant());
    }

    public LoyaltyReward getOwned(UUID providerId, UUID rewardId) {
        LoyaltyReward reward = rewardRepository.findById(rewardId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reward not found: " + rewardId));
        if (!reward.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Reward not found: " + rewardId);
        }
        return reward;
    }

    @Transactional
    public LoyaltyReward create(UUID providerId, String name, String description, LoyaltyRewardType type,
            int pointsCost, BigDecimal discountAmount, String discountCurrency, BigDecimal discountPercentage,
            UUID serviceId, Integer maxRedemptions, Instant startsAt, Instant endsAt, String terms) {
        validate(name, type, pointsCost, discountAmount, discountPercentage, serviceId);
        LoyaltyReward reward = new LoyaltyReward(UUID.randomUUID(), providerId, name, description, type, pointsCost,
                discountAmount, discountCurrency, discountPercentage, serviceId, maxRedemptions, startsAt, endsAt,
                terms, clock.instant());
        return rewardRepository.save(reward);
    }

    @Transactional
    public LoyaltyReward update(UUID providerId, UUID rewardId, String name, String description,
            LoyaltyRewardType type, int pointsCost, BigDecimal discountAmount, String discountCurrency,
            BigDecimal discountPercentage, UUID serviceId, Integer maxRedemptions, Instant startsAt, Instant endsAt,
            String terms) {
        validate(name, type, pointsCost, discountAmount, discountPercentage, serviceId);
        LoyaltyReward reward = getOwned(providerId, rewardId);
        if (maxRedemptions != null && maxRedemptions < reward.getRedemptionsCount()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "maxRedemptions (" + maxRedemptions
                    + ") cannot be lower than the " + reward.getRedemptionsCount() + " redemptions already made");
        }
        reward.applyEdit(name, description, type, pointsCost, discountAmount, discountCurrency, discountPercentage,
                serviceId, maxRedemptions, startsAt, endsAt, terms, clock.instant());
        return rewardRepository.save(reward);
    }

    @Transactional
    public LoyaltyReward setActive(UUID providerId, UUID rewardId, boolean active) {
        LoyaltyReward reward = getOwned(providerId, rewardId);
        reward.setActive(active, clock.instant());
        return rewardRepository.save(reward);
    }

    /** Only allowed when nobody has ever redeemed this reward -- otherwise it's history, see this class's own guidance. */
    @Transactional
    public void delete(UUID providerId, UUID rewardId) {
        LoyaltyReward reward = getOwned(providerId, rewardId);
        if (reward.getRedemptionsCount() > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Cannot delete a reward with redemption "
                    + "history (" + reward.getRedemptionsCount() + " redemptions) -- deactivate it instead");
        }
        rewardRepository.delete(reward);
    }

    private void validate(String name, LoyaltyRewardType type, int pointsCost, BigDecimal discountAmount,
            BigDecimal discountPercentage, UUID serviceId) {
        if (name == null || name.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Reward name must not be blank");
        }
        if (pointsCost <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "pointsCost must be positive");
        }
        switch (type) {
            case FIXED_DISCOUNT -> {
                if (discountAmount == null || discountAmount.signum() <= 0) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "FIXED_DISCOUNT rewards require a positive discountAmount");
                }
            }
            case PERCENTAGE_DISCOUNT -> {
                if (discountPercentage == null || discountPercentage.signum() <= 0
                        || discountPercentage.compareTo(BigDecimal.valueOf(100)) > 0) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "PERCENTAGE_DISCOUNT rewards require a discountPercentage between 0 and 100");
                }
            }
            case FREE_SERVICE -> {
                if (serviceId == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "FREE_SERVICE rewards require a serviceId");
                }
            }
            case CUSTOM -> {
                // No fixed monetary shape required -- the business explains it via terms/description.
            }
        }
    }
}
