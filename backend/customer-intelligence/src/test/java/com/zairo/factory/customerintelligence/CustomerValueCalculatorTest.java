package com.zairo.factory.customerintelligence;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.Test;

class CustomerValueCalculatorTest {

    private static final CustomerIntelligenceProperties.Value VALUE_CONFIG = new CustomerIntelligenceProperties.Value(
            20, new BigDecimal("2000"), 180, 0.30, 0.30, 0.15, 0.15, 0.10);
    private static final CustomerIntelligenceProperties PROPERTIES = new CustomerIntelligenceProperties(
            new CustomerIntelligenceProperties.Interval(2), new CustomerIntelligenceProperties.Retention(1.15, 2.0, 3.0, 60, 120),
            VALUE_CONFIG);

    private final CustomerValueCalculator calculator = new CustomerValueCalculator(PROPERTIES);

    @Test
    void aCustomerWithNoHistoryScoresLowButNotZero() {
        BigDecimal score = calculator.score(new CustomerValueCalculator.Inputs(0, BigDecimal.ZERO, null, null, false,
                Instant.now()));

        // 0 bookings + 0 spend + neutral 0.5 attendance (unknown) + 0 recency (no visit) + 0 repeat,
        // weighted: (0.5*0.15) / 1.0 total weight = 0.075 -> 7.5, not literally zero -- unknown
        // attendance is deliberately neutral rather than punitive (see the calculator's own doc comment).
        assertEquals(0, score.compareTo(new BigDecimal("7.5")));
    }

    @Test
    void aLoyalRecentBigSpenderScoresNearTheTop() {
        BigDecimal score = calculator.score(new CustomerValueCalculator.Inputs(25, new BigDecimal("3000"), 1.0,
                Instant.now(), true, Instant.now()));

        assertTrue(score.compareTo(new BigDecimal("95")) >= 0, "expected a near-max score, got " + score);
    }

    @Test
    void scoreIsMonotonicInCompletedBookings() {
        Instant now = Instant.now();
        BigDecimal fewBookings = calculator.score(new CustomerValueCalculator.Inputs(1, BigDecimal.ZERO, 1.0, now, false, now));
        BigDecimal manyBookings = calculator.score(new CustomerValueCalculator.Inputs(15, BigDecimal.ZERO, 1.0, now, false, now));

        assertTrue(manyBookings.compareTo(fewBookings) > 0);
    }

    @Test
    void recencyDecaysTheScoreAsTheLastVisitAges() {
        Instant now = Instant.now();
        BigDecimal recent = calculator.score(new CustomerValueCalculator.Inputs(5, new BigDecimal("200"), 1.0,
                now.minus(1, ChronoUnit.DAYS), false, now));
        BigDecimal stale = calculator.score(new CustomerValueCalculator.Inputs(5, new BigDecimal("200"), 1.0,
                now.minus(300, ChronoUnit.DAYS), false, now));

        assertTrue(recent.compareTo(stale) > 0);
    }

    @Test
    void scoreNeverExceeds100OrGoesNegative() {
        BigDecimal maxed = calculator.score(new CustomerValueCalculator.Inputs(1000, new BigDecimal("999999"), 1.0,
                Instant.now(), true, Instant.now()));

        assertTrue(maxed.compareTo(new BigDecimal("100")) <= 0);
        assertTrue(maxed.compareTo(BigDecimal.ZERO) >= 0);
    }
}
