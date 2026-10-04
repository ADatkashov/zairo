package com.zairo.factory.loyalty;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Business-admin request/response shapes -- see {@link LoyaltyAdminController}. */
public final class LoyaltyAdminDtos {

    private LoyaltyAdminDtos() {
    }

    public record LoyaltySettingsResponse(UUID providerId, boolean enabled, String name, String description,
            int fixedPointsPerBooking, BigDecimal pointsPerCurrencyUnit, int firstBookingBonusPoints,
            int repeatVisitBonusPoints, int repeatVisitThreshold, int reviewBonusPoints,
            BigDecimal pointsPerCurrencyUnitRedemption, Integer minRedemptionPoints,
            Integer maxRedemptionPointsPerBooking, boolean pointsExpireEnabled, Integer pointsExpirationMonths,
            Integer dailyEarningPointsCap, Integer monthlyEarningPointsCap, int birthdayBonusPoints) {

        static LoyaltySettingsResponse from(LoyaltyProgram p) {
            return new LoyaltySettingsResponse(p.getProviderId(), p.isEnabled(), p.getName(), p.getDescription(),
                    p.getFixedPointsPerBooking(), p.getPointsPerCurrencyUnit(), p.getFirstBookingBonusPoints(),
                    p.getRepeatVisitBonusPoints(), p.getRepeatVisitThreshold(), p.getReviewBonusPoints(),
                    p.getPointsPerCurrencyUnitRedemption(), p.getMinRedemptionPoints(),
                    p.getMaxRedemptionPointsPerBooking(), p.isPointsExpireEnabled(), p.getPointsExpirationMonths(),
                    p.getDailyEarningPointsCap(), p.getMonthlyEarningPointsCap(),
                    p.getBirthdayBonusPoints());
        }
    }

    public record UpdateLoyaltySettingsRequest(boolean enabled, String name, String description,
            int fixedPointsPerBooking, BigDecimal pointsPerCurrencyUnit, int firstBookingBonusPoints,
            int repeatVisitBonusPoints, int repeatVisitThreshold, int reviewBonusPoints,
            BigDecimal pointsPerCurrencyUnitRedemption, Integer minRedemptionPoints,
            Integer maxRedemptionPointsPerBooking, boolean pointsExpireEnabled, Integer pointsExpirationMonths,
            Integer dailyEarningPointsCap, Integer monthlyEarningPointsCap, int birthdayBonusPoints) {
    }

    /**
     * One opted-in member with a birthday coming up. Month/day only -- the birth year (age) is deliberately not
     * exposed to the business.
     */
    public record BirthdayResponse(UUID userId, String displayName, int month, int day, int daysUntil,
            int bonusPoints, boolean bonusAwarded) {
    }

    public record MilestoneResponse(UUID id, int visitsRequired, int pointsAwarded, String label) {
        static MilestoneResponse from(LoyaltyMilestoneRule m) {
            return new MilestoneResponse(m.getId(), m.getVisitsRequired(), m.getPointsAwarded(), m.getLabel());
        }
    }

    public record MilestoneRequest(int visitsRequired, int pointsAwarded, String label) {
    }

    public record ReplaceMilestonesRequest(List<MilestoneRequest> milestones) {
    }

    public record TierResponse(UUID id, String name, int minLifetimePoints) {
        static TierResponse from(LoyaltyTierRule t) {
            return new TierResponse(t.getId(), t.getName(), t.getMinLifetimePoints());
        }
    }

    public record TierRequest(String name, int minLifetimePoints) {
    }

    public record ReplaceTiersRequest(List<TierRequest> tiers) {
    }

    public record OverviewResponse(long totalMembers, long activeMembers, long totalPointsIssued,
            long totalPointsRedeemed, long outstandingPointsLiability, long rewardsRedeemed) {
        static OverviewResponse from(LoyaltyDashboardService.Overview o) {
            return new OverviewResponse(o.totalMembers(), o.activeMembers(), o.totalPointsIssued(),
                    o.totalPointsRedeemed(), o.outstandingPointsLiability(), o.rewardsRedeemed());
        }
    }

    public record CustomerInsightResponse(UUID userId, String displayName, String email, int pointsBalance,
            int lifetimeEarned, int lifetimeRedeemed, int completedVisits, Instant lastActivityAt,
            int pointsExpiringSoon30d, String retentionStatus) {
    }

    public record RewardResponse(UUID id, String name, String description, LoyaltyRewardType type, int pointsCost,
            BigDecimal discountAmount, String discountCurrency, BigDecimal discountPercentage, UUID serviceId,
            Integer maxRedemptions, int redemptionsCount, Instant startsAt, Instant endsAt, boolean active,
            String terms) {
        static RewardResponse from(LoyaltyReward r) {
            return new RewardResponse(r.getId(), r.getName(), r.getDescription(), r.getType(), r.getPointsCost(),
                    r.getDiscountAmount(), r.getDiscountCurrency(), r.getDiscountPercentage(), r.getServiceId(),
                    r.getMaxRedemptions(), r.getRedemptionsCount(), r.getStartsAt(), r.getEndsAt(), r.isActive(),
                    r.getTerms());
        }
    }

    public record RewardRequest(String name, String description, LoyaltyRewardType type, int pointsCost,
            BigDecimal discountAmount, String discountCurrency, BigDecimal discountPercentage, UUID serviceId,
            Integer maxRedemptions, Instant startsAt, Instant endsAt, String terms) {
    }

    public record AdjustPointsRequest(int delta, String reason) {
    }

    public record RedemptionAdminResponse(UUID id, UUID userId, UUID rewardId, String rewardName, int pointsSpent,
            String code, LoyaltyRedemptionStatus status, Instant createdAt, Instant expiresAt, UUID appliedBookingId,
            Instant appliedAt) {
        static RedemptionAdminResponse from(LoyaltyRedemption r) {
            return new RedemptionAdminResponse(r.getId(), r.getUserId(), r.getRewardId(), r.getRewardNameSnapshot(),
                    r.getPointsSpent(), r.getCode(), r.getStatus(), r.getCreatedAt(), r.getExpiresAt(),
                    r.getAppliedBookingId(), r.getAppliedAt());
        }
    }

    public record ApplyRedemptionRequest(UUID bookingId) {
    }

    public record CancelRedemptionRequest(String reason) {
    }
}
