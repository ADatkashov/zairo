package com.zairo.factory.customerintelligence;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.Test;

class RetentionCalculatorTest {

    private static final CustomerIntelligenceProperties.Retention CONFIG = new CustomerIntelligenceProperties.Retention(
            1.15, 2.0, 3.0, 60, 120);

    @Test
    void noCompletedBookingEverIsNew() {
        assertEquals(RetentionStatus.NEW, RetentionCalculator.classify(null, null, Instant.now(), CONFIG));
    }

    @Test
    void withinTheEstablishedIntervalIsActive() {
        Instant now = Instant.now();
        Instant lastVisit = now.minus(20, ChronoUnit.DAYS);

        assertEquals(RetentionStatus.ACTIVE, RetentionCalculator.classify(lastVisit, 28, now, CONFIG));
    }

    @Test
    void justPastTheIntervalIsDueForRebooking() {
        Instant now = Instant.now();
        // 30 days since last visit, 28-day cadence -- 1.07x, past dueSoonFactor (1.15 * 28 = 32.2)? no --
        // pick a value clearly between dueSoonFactor and atRiskFactor: 1.5x = 42 days.
        Instant lastVisit = now.minus(42, ChronoUnit.DAYS);

        assertEquals(RetentionStatus.DUE_FOR_REBOOKING, RetentionCalculator.classify(lastVisit, 28, now, CONFIG));
    }

    @Test
    void wellPastTheIntervalIsAtRisk() {
        // The task brief's own worked example: usually every 28 days, hasn't booked for 60 -- 2.14x.
        Instant now = Instant.now();
        Instant lastVisit = now.minus(60, ChronoUnit.DAYS);

        assertEquals(RetentionStatus.AT_RISK, RetentionCalculator.classify(lastVisit, 28, now, CONFIG));
    }

    @Test
    void farPastTheIntervalIsInactive() {
        Instant now = Instant.now();
        Instant lastVisit = now.minus(100, ChronoUnit.DAYS);

        assertEquals(RetentionStatus.INACTIVE, RetentionCalculator.classify(lastVisit, 28, now, CONFIG));
    }

    @Test
    void aSingleVisitWithNoEstablishedIntervalUsesTheFlatActiveWindow() {
        Instant now = Instant.now();
        Instant lastVisit = now.minus(30, ChronoUnit.DAYS);

        assertEquals(RetentionStatus.ACTIVE, RetentionCalculator.classify(lastVisit, null, now, CONFIG));
    }

    @Test
    void aSingleOldVisitWithNoEstablishedIntervalIsAtRiskThenInactive() {
        Instant now = Instant.now();

        assertEquals(RetentionStatus.AT_RISK,
                RetentionCalculator.classify(now.minus(90, ChronoUnit.DAYS), null, now, CONFIG));
        assertEquals(RetentionStatus.INACTIVE,
                RetentionCalculator.classify(now.minus(200, ChronoUnit.DAYS), null, now, CONFIG));
    }
}
