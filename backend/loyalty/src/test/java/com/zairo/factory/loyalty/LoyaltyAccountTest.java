package com.zairo.factory.loyalty;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class LoyaltyAccountTest {

    @Test
    void creditIncreasesBalanceAndLifetimeEarned() {
        LoyaltyAccount account = new LoyaltyAccount(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                Instant.now());

        account.credit(100, Instant.now());
        account.credit(50, Instant.now());

        assertThat(account.getPointsBalance()).isEqualTo(150);
        assertThat(account.getLifetimeEarned()).isEqualTo(150);
    }

    @Test
    void debitForRedemptionTracksLifetimeRedeemedNotExpired() {
        LoyaltyAccount account = new LoyaltyAccount(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                Instant.now());
        account.credit(100, Instant.now());

        account.debit(40, LoyaltyTransactionType.REDEEMED, Instant.now());

        assertThat(account.getPointsBalance()).isEqualTo(60);
        assertThat(account.getLifetimeRedeemed()).isEqualTo(40);
        assertThat(account.getLifetimeExpired()).isEqualTo(0);
    }

    @Test
    void debitForExpirationTracksLifetimeExpiredNotRedeemed() {
        LoyaltyAccount account = new LoyaltyAccount(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                Instant.now());
        account.credit(100, Instant.now());

        account.debit(25, LoyaltyTransactionType.EXPIRED, Instant.now());

        assertThat(account.getPointsBalance()).isEqualTo(75);
        assertThat(account.getLifetimeExpired()).isEqualTo(25);
        assertThat(account.getLifetimeRedeemed()).isEqualTo(0);
    }

    @Test
    void debitingMoreThanTheBalanceIsRejected() {
        LoyaltyAccount account = new LoyaltyAccount(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                Instant.now());
        account.credit(10, Instant.now());

        assertThatThrownBy(() -> account.debit(11, LoyaltyTransactionType.REDEEMED, Instant.now()))
                .isInstanceOf(IllegalStateException.class);
        assertThat(account.getPointsBalance()).isEqualTo(10); // unchanged
    }
}
