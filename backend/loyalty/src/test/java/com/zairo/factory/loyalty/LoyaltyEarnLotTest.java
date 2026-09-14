package com.zairo.factory.loyalty;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class LoyaltyEarnLotTest {

    @Test
    void consumeTakesNoMoreThanWhatsRemaining() {
        LoyaltyEarnLot lot = new LoyaltyEarnLot(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), 100, Instant.now(), null);

        int taken = lot.consume(60);

        assertThat(taken).isEqualTo(60);
        assertThat(lot.getPointsRemaining()).isEqualTo(40);
    }

    @Test
    void consumingMoreThanRemainingIsClampedToWhatsAvailable() {
        LoyaltyEarnLot lot = new LoyaltyEarnLot(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), 30, Instant.now(), null);

        int taken = lot.consume(100);

        assertThat(taken).isEqualTo(30);
        assertThat(lot.getPointsRemaining()).isEqualTo(0);
    }

    @Test
    void consumingFromAnExhaustedLotTakesNothing() {
        LoyaltyEarnLot lot = new LoyaltyEarnLot(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), 10, Instant.now(), null);
        lot.consume(10);

        int taken = lot.consume(5);

        assertThat(taken).isEqualTo(0);
        assertThat(lot.getPointsRemaining()).isEqualTo(0);
    }
}
