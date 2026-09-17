package com.zairo.factory.loyalty;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class LoyaltyProgramServiceTierTest {

    private final UUID programId = UUID.randomUUID();

    @Test
    void noTiersConfiguredMeansNoCurrentTier() {
        assertThat(LoyaltyProgramService.currentTier(List.of(), 5000)).isNull();
    }

    @Test
    void belowTheLowestThresholdMeansNoCurrentTier() {
        List<LoyaltyTierRule> tiers = List.of(tier("Bronze", 1000), tier("Silver", 5000));

        assertThat(LoyaltyProgramService.currentTier(tiers, 500)).isNull();
    }

    @Test
    void exactlyAtAThresholdCountsAsReachingIt() {
        List<LoyaltyTierRule> tiers = List.of(tier("Bronze", 0), tier("Silver", 1000), tier("Gold", 5000));

        assertThat(LoyaltyProgramService.currentTier(tiers, 1000).getName()).isEqualTo("Silver");
    }

    @Test
    void theHighestReachedTierWins() {
        List<LoyaltyTierRule> tiers = List.of(tier("Bronze", 0), tier("Silver", 1000), tier("Gold", 5000));

        assertThat(LoyaltyProgramService.currentTier(tiers, 12000).getName()).isEqualTo("Gold");
    }

    private LoyaltyTierRule tier(String name, int minLifetimePoints) {
        return new LoyaltyTierRule(UUID.randomUUID(), programId, name, minLifetimePoints);
    }
}
