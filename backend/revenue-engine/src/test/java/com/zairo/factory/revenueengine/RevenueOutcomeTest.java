package com.zairo.factory.revenueengine;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RevenueOutcomeTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T12:00:00Z");

    private static RevenueOutcome outcome() {
        return new RevenueOutcome(UUID.randomUUID(), ActionType.SMART_FILL, UUID.randomUUID(), UUID.randomUUID(),
                new BigDecimal("8000"), "KZT", T0);
    }

    @Test
    void newOutcomeIsUnresolved() {
        RevenueOutcome o = outcome();

        assertThat(o.getRecovered()).isNull();
        assertThat(o.getActualRevenue()).isNull();
        assertThat(o.getResolvedAt()).isNull();
        assertThat(o.getExpectedValue()).isEqualByComparingTo("8000");
    }

    @Test
    void resolvingRecordsTheActualRevenueAndWhen() {
        RevenueOutcome o = outcome();

        o.resolve(new BigDecimal("7500"), "KZT", true, T1);

        assertThat(o.getRecovered()).isTrue();
        assertThat(o.getActualRevenue()).isEqualByComparingTo("7500");
        assertThat(o.getResolvedAt()).isEqualTo(T1);
    }

    @Test
    void resolvingWithoutACurrencyKeepsTheOriginalOne() {
        RevenueOutcome o = outcome();

        o.resolve(BigDecimal.ZERO, null, false, T1);

        assertThat(o.getCurrency()).isEqualTo("KZT");
        assertThat(o.getRecovered()).isFalse();
    }

    @Test
    void resolvingWithACurrencyReplacesIt() {
        RevenueOutcome o = outcome();

        o.resolve(new BigDecimal("10"), "USD", true, T1);

        assertThat(o.getCurrency()).isEqualTo("USD");
    }
}
