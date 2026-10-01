package com.zairo.factory.payments;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

/**
 * The task's own worked example: 15 000 KZT at 10% -> 1 500 platform fee,
 * 13 500 business amount. See {@link CommissionCalculator}'s own doc
 * comment for why the business amount is derived by subtraction, never
 * rounded independently.
 */
class CommissionCalculatorTest {

    @Test
    void splits15000KztAt10PercentIntoTheTasksOwnWorkedExample() {
        CommissionCalculator calculator = new CommissionCalculator(new BigDecimal("0.10"));
        CommissionCalculator.Split split = calculator.split(new BigDecimal("15000"), "KZT");

        // BigDecimal.equals is scale-sensitive (5 != 5.00) — the computed
        // values carry KZT's 2-decimal scale from CommissionCalculator's own
        // rounding, so the expected literals must match it exactly.
        assertEquals(new BigDecimal("1500.00"), split.platformFee());
        assertEquals(new BigDecimal("13500.00"), split.businessAmount());
        assertEquals(new BigDecimal("0.10"), split.rate());
    }

    @Test
    void businessAmountPlusPlatformFeeAlwaysEqualsTheOriginalAmountEvenWhenRoundingIsInvolved() {
        CommissionCalculator calculator = new CommissionCalculator(new BigDecimal("0.10"));
        BigDecimal amount = new BigDecimal("19.99");
        CommissionCalculator.Split split = calculator.split(amount, "USD");

        assertEquals(amount, split.businessAmount().add(split.platformFee()));
    }

    @Test
    void aZeroRateMeansNoCommissionAtAll() {
        CommissionCalculator calculator = new CommissionCalculator(BigDecimal.ZERO);
        CommissionCalculator.Split split = calculator.split(new BigDecimal("100.00"), "USD");

        assertEquals(new BigDecimal("0.00"), split.platformFee());
        assertEquals(new BigDecimal("100.00"), split.businessAmount());
    }

    @Test
    void rejectsAnOutOfRangeRateAtConstructionRatherThanAtSplitTime() {
        assertThrows(IllegalStateException.class, () -> new CommissionCalculator(new BigDecimal("1.5")));
        assertThrows(IllegalStateException.class, () -> new CommissionCalculator(new BigDecimal("-0.1")));
    }
}
