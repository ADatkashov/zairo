package com.zairo.factory.loyalty;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class LoyaltyLedgerServiceComputeExpiryTest {

    private final Instant now = Instant.parse("2026-01-15T00:00:00Z");

    @Test
    void nullProgramMeansPointsNeverExpire() {
        assertThat(LoyaltyLedgerService.computeExpiry(null, now)).isNull();
    }

    @Test
    void expirationDisabledMeansPointsNeverExpire() {
        LoyaltyProgram program = programWithExpiration(false, 12);

        assertThat(LoyaltyLedgerService.computeExpiry(program, now)).isNull();
    }

    @Test
    void expirationEnabledComputesAFutureDateNMonthsOut() {
        LoyaltyProgram program = programWithExpiration(true, 12);

        Instant expiry = LoyaltyLedgerService.computeExpiry(program, now);

        assertThat(expiry).isEqualTo(now.atZone(ZoneOffset.UTC).plusMonths(12).toInstant());
    }

    private LoyaltyProgram programWithExpiration(boolean enabled, Integer months) {
        LoyaltyProgram program = new LoyaltyProgram(UUID.randomUUID(), UUID.randomUUID(), "Test Program", now);
        program.applySettings(true, "Test Program", null, 0, BigDecimal.ZERO, 0, 0, 2, 0, null, null, null, enabled,
                months, null, null, 0, now);
        return program;
    }
}
