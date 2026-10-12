package com.zairo.factory.workforce;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit test -- time off decides which generated slots a worker loses. */
class WorkerTimeOffTest {

    private static Instant at(String time) {
        return Instant.parse("2026-10-12T" + time + ":00Z");
    }

    /** Time off from 10:00 to 12:00. */
    private static WorkerTimeOff offTenToTwelve() {
        return new WorkerTimeOff(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), at("10:00"), at("12:00"),
                "dentist", UUID.randomUUID(), at("08:00"));
    }

    @Test
    void windowInsideTheTimeOffOverlaps() {
        assertThat(offTenToTwelve().overlaps(at("10:30"), at("11:00"))).isTrue();
    }

    @Test
    void windowCoveringTheWholeTimeOffOverlaps() {
        assertThat(offTenToTwelve().overlaps(at("09:00"), at("13:00"))).isTrue();
    }

    @Test
    void windowStraddlingEitherEdgeOverlaps() {
        assertThat(offTenToTwelve().overlaps(at("09:30"), at("10:30"))).isTrue();
        assertThat(offTenToTwelve().overlaps(at("11:30"), at("12:30"))).isTrue();
    }

    @Test
    void windowsTouchingTheEdgesDoNotOverlap() {
        assertThat(offTenToTwelve().overlaps(at("09:00"), at("10:00"))).isFalse();
        assertThat(offTenToTwelve().overlaps(at("12:00"), at("13:00"))).isFalse();
    }

    @Test
    void windowsFullyOutsideDoNotOverlap() {
        assertThat(offTenToTwelve().overlaps(at("07:00"), at("08:00"))).isFalse();
        assertThat(offTenToTwelve().overlaps(at("14:00"), at("15:00"))).isFalse();
    }
}
