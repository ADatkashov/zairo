package com.zairo.factory.smartfill;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The anti-spam rules, checked against fake repositories (Mockito) -- no Spring context, no database. */
class NotificationPolicyTest {

    private static final Instant NOW = Instant.parse("2026-10-12T12:00:00Z");
    private static final UUID USER = UUID.randomUUID();
    private static final UUID PROVIDER = UUID.randomUUID();

    private CandidateOfferRepository offers;
    private SmartFillUserPreferenceRepository preferences;
    private NotificationPolicy policy;

    @BeforeEach
    void setUp() {
        offers = mock(CandidateOfferRepository.class);
        preferences = mock(SmartFillUserPreferenceRepository.class);
        // cooldown 6h, business cooldown 7d, decline cooldown 14d, max 3/day, max 10/week
        SmartFillProperties props = new SmartFillProperties(null, new SmartFillProperties.AntiSpam(6, 7, 14, 3, 10),
                null);
        policy = new NotificationPolicy(offers, preferences, props);
        when(preferences.findByUserId(USER)).thenReturn(Optional.empty());
    }

    @Test
    void aFreshUserWithNoHistoryMayBeOffered() {
        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isTrue();
    }

    @Test
    void anOptedOutUserIsNeverOffered() {
        SmartFillUserPreference pref = mock(SmartFillUserPreference.class);
        when(pref.isOptedOut()).thenReturn(true);
        when(preferences.findByUserId(USER)).thenReturn(Optional.of(pref));

        assertThat(policy.isOptedOut(USER)).isTrue();
        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isFalse();
    }

    @Test
    void aUserWhoOptedBackInIsOffered() {
        SmartFillUserPreference pref = mock(SmartFillUserPreference.class);
        when(pref.isOptedOut()).thenReturn(false);
        when(preferences.findByUserId(USER)).thenReturn(Optional.of(pref));

        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isTrue();
    }

    @Test
    void aNotificationInsideThePerUserCooldownBlocksTheOffer() {
        Instant sixHoursAgo = NOW.minus(6, ChronoUnit.HOURS);
        when(offers.countByUserIdAndNotifiedAtAfter(USER, sixHoursAgo)).thenReturn(1L);

        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isFalse();
    }

    @Test
    void aRecentNotificationFromTheSameBusinessBlocksTheOffer() {
        when(offers.existsByUserIdAndProviderIdAndNotifiedAtAfter(USER, PROVIDER, NOW.minus(7, ChronoUnit.DAYS)))
                .thenReturn(true);

        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isFalse();
    }

    @Test
    void aRecentDeclineFromTheSameBusinessBlocksTheOffer() {
        when(offers.existsByUserIdAndProviderIdAndStatusAndRespondedAtAfter(USER, PROVIDER,
                CandidateOfferStatus.DECLINED, NOW.minus(14, ChronoUnit.DAYS))).thenReturn(true);

        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isFalse();
    }

    @Test
    void reachingTheDailyLimitBlocksTheOffer() {
        when(offers.countByUserIdAndNotifiedAtAfter(eq(USER), eq(NOW.minus(1, ChronoUnit.DAYS)))).thenReturn(3L);

        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isFalse();
    }

    @Test
    void justUnderTheDailyLimitStillAllowsTheOffer() {
        when(offers.countByUserIdAndNotifiedAtAfter(eq(USER), eq(NOW.minus(1, ChronoUnit.DAYS)))).thenReturn(2L);

        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isTrue();
    }

    @Test
    void reachingTheWeeklyLimitBlocksTheOffer() {
        when(offers.countByUserIdAndNotifiedAtAfter(eq(USER), eq(NOW.minus(7, ChronoUnit.DAYS)))).thenReturn(10L);

        assertThat(policy.mayOffer(USER, PROVIDER, NOW)).isFalse();
    }
}
