package com.zairo.factory.loyalty;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class LoyaltyRewardTest {

    private final Instant now = Instant.now();

    @Test
    void anActiveRewardWithNoDatesOrLimitIsAlwaysRedeemable() {
        LoyaltyReward reward = reward(null, null, null, true);

        assertThat(reward.isRedeemableAt(now)).isTrue();
    }

    @Test
    void anInactiveRewardIsNeverRedeemable() {
        LoyaltyReward reward = reward(null, null, null, false);

        assertThat(reward.isRedeemableAt(now)).isFalse();
    }

    @Test
    void aRewardBeforeItsStartDateIsNotYetRedeemable() {
        LoyaltyReward reward = reward(now.plus(1, ChronoUnit.DAYS), null, null, true);

        assertThat(reward.isRedeemableAt(now)).isFalse();
    }

    @Test
    void aRewardPastItsEndDateIsNoLongerRedeemable() {
        LoyaltyReward reward = reward(null, now.minus(1, ChronoUnit.DAYS), null, true);

        assertThat(reward.isRedeemableAt(now)).isFalse();
    }

    @Test
    void aRewardThatHasHitItsMaxRedemptionsIsNoLongerRedeemable() {
        LoyaltyReward reward = reward(null, null, 3, true);
        reward.incrementRedemptions();
        reward.incrementRedemptions();
        reward.incrementRedemptions();

        assertThat(reward.isRedeemableAt(now)).isFalse();
    }

    @Test
    void aRewardBelowItsMaxRedemptionsIsStillRedeemable() {
        LoyaltyReward reward = reward(null, null, 3, true);
        reward.incrementRedemptions();

        assertThat(reward.isRedeemableAt(now)).isTrue();
    }

    private LoyaltyReward reward(Instant startsAt, Instant endsAt, Integer maxRedemptions, boolean active) {
        LoyaltyReward reward = new LoyaltyReward(UUID.randomUUID(), UUID.randomUUID(), "Test Reward", null,
                LoyaltyRewardType.FIXED_DISCOUNT, 100, new BigDecimal("10.00"), "USD", null, null, maxRedemptions,
                startsAt, endsAt, null, now);
        reward.setActive(active, now);
        return reward;
    }
}
