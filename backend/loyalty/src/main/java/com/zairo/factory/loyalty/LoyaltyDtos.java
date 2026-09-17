package com.zairo.factory.loyalty;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Customer-facing request/response shapes -- see {@link LoyaltyController}. */
public final class LoyaltyDtos {

    private LoyaltyDtos() {
    }

    public record LoyaltyBusinessSummaryResponse(UUID providerId, String providerName, boolean programEnabled,
            int pointsBalance, int lifetimeEarned, String tierName, int pointsExpiringSoon30d) {
    }

    public record NextMilestoneResponse(String label, int visitsRequired, int visitsRemaining, int pointsAwarded) {
    }

    public record LoyaltyBusinessDetailResponse(UUID providerId, String providerName, boolean programEnabled,
            String programName, String programDescription, int pointsBalance, int lifetimeEarned,
            int lifetimeRedeemed, int completedVisits, String tierName, int pointsExpiringSoon30d,
            List<String> waysToEarn, NextMilestoneResponse nextMilestone, int availableRewardsCount) {

        static LoyaltyBusinessDetailResponse of(String providerName, LoyaltyProgram program, LoyaltyAccount account,
                String tierName, int expiringSoon, NextMilestoneResponse nextMilestone, int availableRewardsCount) {
            boolean enabled = program != null && program.isEnabled();
            List<String> waysToEarn = new ArrayList<>();
            if (program != null) {
                if (program.getFixedPointsPerBooking() > 0) {
                    waysToEarn.add(program.getFixedPointsPerBooking() + " points per completed booking");
                }
                if (program.getPointsPerCurrencyUnit() != null && program.getPointsPerCurrencyUnit().signum() > 0) {
                    waysToEarn.add(program.getPointsPerCurrencyUnit() + " points per unit spent");
                }
                if (program.getFirstBookingBonusPoints() > 0) {
                    waysToEarn.add(program.getFirstBookingBonusPoints() + " bonus points on your first booking");
                }
                if (program.getRepeatVisitBonusPoints() > 0) {
                    waysToEarn.add(program.getRepeatVisitBonusPoints() + " bonus points on your "
                            + ordinal(program.getRepeatVisitThreshold()) + " visit");
                }
                if (program.getReviewBonusPoints() > 0) {
                    waysToEarn.add(program.getReviewBonusPoints() + " bonus points for leaving a review");
                }
            }
            return new LoyaltyBusinessDetailResponse(account.getProviderId(), providerName, enabled,
                    program == null ? null : program.getName(), program == null ? null : program.getDescription(),
                    account.getPointsBalance(), account.getLifetimeEarned(), account.getLifetimeRedeemed(),
                    account.getCompletedVisits(), tierName, expiringSoon, waysToEarn, nextMilestone,
                    availableRewardsCount);
        }

        private static String ordinal(int n) {
            if (n % 100 >= 11 && n % 100 <= 13) {
                return n + "th";
            }
            return switch (n % 10) {
                case 1 -> n + "st";
                case 2 -> n + "nd";
                case 3 -> n + "rd";
                default -> n + "th";
            };
        }
    }

    public record LoyaltyRewardResponse(UUID id, String name, String description, LoyaltyRewardType type,
            int pointsCost, BigDecimal discountAmount, String discountCurrency, BigDecimal discountPercentage,
            UUID serviceId, Instant endsAt, String terms, boolean affordable) {

        static LoyaltyRewardResponse of(LoyaltyReward reward, int currentBalance) {
            return new LoyaltyRewardResponse(reward.getId(), reward.getName(), reward.getDescription(),
                    reward.getType(), reward.getPointsCost(), reward.getDiscountAmount(),
                    reward.getDiscountCurrency(), reward.getDiscountPercentage(), reward.getServiceId(),
                    reward.getEndsAt(), reward.getTerms(), currentBalance >= reward.getPointsCost());
        }
    }

    public record LoyaltyTransactionResponse(UUID id, LoyaltyTransactionType type, int pointsDelta, int balanceAfter,
            String reason, Instant createdAt, Instant expiresAt, UUID bookingId) {

        static LoyaltyTransactionResponse from(LoyaltyTransaction tx) {
            return new LoyaltyTransactionResponse(tx.getId(), tx.getType(), tx.getPointsDelta(), tx.getBalanceAfter(),
                    tx.getReason(), tx.getCreatedAt(), tx.getExpiresAt(), tx.getBookingId());
        }
    }

    public record LoyaltyRedemptionResponse(UUID id, UUID providerId, String providerName, UUID rewardId,
            String rewardName, LoyaltyRewardType rewardType, int pointsSpent, String code,
            LoyaltyRedemptionStatus status, Instant createdAt, Instant expiresAt, UUID appliedBookingId,
            Instant appliedAt) {

        static LoyaltyRedemptionResponse of(LoyaltyRedemption redemption, String providerName) {
            return new LoyaltyRedemptionResponse(redemption.getId(), redemption.getProviderId(), providerName,
                    redemption.getRewardId(), redemption.getRewardNameSnapshot(), redemption.getRewardTypeSnapshot(),
                    redemption.getPointsSpent(), redemption.getCode(), redemption.getStatus(),
                    redemption.getCreatedAt(), redemption.getExpiresAt(), redemption.getAppliedBookingId(),
                    redemption.getAppliedAt());
        }
    }

    public record CancelRedemptionRequest(String reason) {
    }
}
