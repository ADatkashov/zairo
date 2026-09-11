package com.zairo.factory.smartfill;

import java.util.Map;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code smartfill.*} -- see application.yml for the actual {@code
 * ${ENV_VAR:default}} values. Every tunable the task this module was built
 * from called out (batch size, stage delay, cooldowns, notification limits,
 * scoring weights, campaign expiration, max candidates) lives here, not
 * hardcoded in {@link CandidateFinder}/{@link SmartFillCampaignService}/
 * {@link RuleBasedCandidateScorer} -- same reasoning as {@code
 * paymentprovider.freedompay.FreedomPayProperties}, grouped related fields
 * instead of scattered {@code @Value}s, since there are many of them here
 * too.
 */
@ConfigurationProperties(prefix = "smartfill")
public record SmartFillProperties(Staging staging, AntiSpam antispam, Scoring scoring) {

    /** Batch size/cadence for the staged rollout -- see SmartFillCampaignService/SmartFillCampaignJob. */
    public record Staging(
            int batchSize,
            int stageDelayMinutes,
            int maxStages,
            int maxCandidatesPerCampaign,
            /** Hard ceiling regardless of the slot's own start time -- a campaign never outlives this. */
            int campaignMaxDurationMinutes) {
    }

    /** See NotificationPolicy -- every check it makes reads one of these. */
    public record AntiSpam(
            /** Minimum gap between any two Smart Fill notifications to the same user, from any business. */
            int perUserCooldownHours,
            /** Minimum gap between two notifications from the same provider to the same user. */
            int perBusinessCooldownDays,
            /** After a candidate declines an offer, don't offer them anything from the same provider for this long. */
            int declineCooldownDays,
            int maxDailyNotificationsPerUser,
            int maxWeeklyNotificationsPerUser) {
    }

    /** See RuleBasedCandidateScorer -- weights keyed by ScoringFactor, plus the lookback windows its signals use. */
    public record Scoring(
            int recentVisitWindowDays,
            int recentEngagementWindowDays,
            int suitableTimeToleranceMinutes,
            Map<ScoringFactor, Integer> weights) {

        /** A factor with no configured weight scores 0 rather than throwing -- a missing entry is not a code path a candidate should ever fail on. */
        public int weightOf(ScoringFactor factor) {
            return weights.getOrDefault(factor, 0);
        }
    }
}
