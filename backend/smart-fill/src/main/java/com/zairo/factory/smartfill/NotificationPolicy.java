package com.zairo.factory.smartfill;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Anti-spam: whether a specific candidate may be offered anything from a
 * specific provider right now. Every check reads a configurable value from
 * {@link SmartFillProperties.AntiSpam} -- see application.yml's {@code
 * smartfill.antispam} block -- so tuning limits never means touching this
 * class. Checked twice: once by {@link CandidateFinder} while building a
 * campaign's pool, and again by {@link SmartFillCampaignService} right
 * before a later stage actually notifies someone (limits/cooldowns are a
 * moving target between a campaign's creation and a stage sent minutes
 * later).
 */
@Component
class NotificationPolicy {

    private final CandidateOfferRepository candidateOfferRepository;
    private final SmartFillUserPreferenceRepository preferenceRepository;
    private final SmartFillProperties properties;

    NotificationPolicy(CandidateOfferRepository candidateOfferRepository,
            SmartFillUserPreferenceRepository preferenceRepository, SmartFillProperties properties) {
        this.candidateOfferRepository = candidateOfferRepository;
        this.preferenceRepository = preferenceRepository;
        this.properties = properties;
    }

    boolean mayOffer(UUID userId, UUID providerId, Instant now) {
        if (isOptedOut(userId)) {
            return false;
        }

        SmartFillProperties.AntiSpam antiSpam = properties.antispam();

        Instant userCooldownCutoff = now.minus(antiSpam.perUserCooldownHours(), ChronoUnit.HOURS);
        if (candidateOfferRepository.countByUserIdAndNotifiedAtAfter(userId, userCooldownCutoff) > 0) {
            return false;
        }

        Instant businessCooldownCutoff = now.minus(antiSpam.perBusinessCooldownDays(), ChronoUnit.DAYS);
        if (candidateOfferRepository.existsByUserIdAndProviderIdAndNotifiedAtAfter(userId, providerId,
                businessCooldownCutoff)) {
            return false;
        }

        Instant declineCutoff = now.minus(antiSpam.declineCooldownDays(), ChronoUnit.DAYS);
        if (candidateOfferRepository.existsByUserIdAndProviderIdAndStatusAndRespondedAtAfter(userId, providerId,
                CandidateOfferStatus.DECLINED, declineCutoff)) {
            return false;
        }

        Instant dayCutoff = now.minus(1, ChronoUnit.DAYS);
        if (candidateOfferRepository.countByUserIdAndNotifiedAtAfter(userId, dayCutoff)
                >= antiSpam.maxDailyNotificationsPerUser()) {
            return false;
        }

        Instant weekCutoff = now.minus(7, ChronoUnit.DAYS);
        return candidateOfferRepository.countByUserIdAndNotifiedAtAfter(userId, weekCutoff)
                < antiSpam.maxWeeklyNotificationsPerUser();
    }

    boolean isOptedOut(UUID userId) {
        return preferenceRepository.findByUserId(userId).map(SmartFillUserPreference::isOptedOut).orElse(false);
    }
}
