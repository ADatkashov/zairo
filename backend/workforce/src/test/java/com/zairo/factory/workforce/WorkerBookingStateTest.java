package com.zairo.factory.workforce;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class WorkerBookingStateTest {

    private static final Instant T0 = Instant.parse("2026-10-12T09:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant T2 = Instant.parse("2026-10-12T11:00:00Z");

    private static WorkerBookingState state() {
        return new WorkerBookingState(UUID.randomUUID(), UUID.randomUUID(), WorkerBookingState.Preference.SPECIFIC,
                T0);
    }

    @Test
    void newStateIsNeitherConfirmedNorDeclined() {
        WorkerBookingState s = state();

        assertThat(s.getConfirmedAt()).isNull();
        assertThat(s.getDeclinedAt()).isNull();
        assertThat(s.getPreference()).isEqualTo(WorkerBookingState.Preference.SPECIFIC);
    }

    @Test
    void confirmingTwiceKeepsTheFirstTimestamp() {
        WorkerBookingState s = state();

        s.confirm(T1);
        s.confirm(T2);

        assertThat(s.getConfirmedAt()).isEqualTo(T1);
    }

    @Test
    void decliningTwiceKeepsTheFirstTimeAndReason() {
        WorkerBookingState s = state();

        s.requestDecline(T1, "ill");
        s.requestDecline(T2, "changed my mind");

        assertThat(s.getDeclinedAt()).isEqualTo(T1);
        assertThat(s.getDeclineReason()).isEqualTo("ill");
    }

    @Test
    void reassigningHandsTheBookingToANewWorkerWithACleanSlate() {
        WorkerBookingState s = state();
        s.confirm(T1);
        s.requestDecline(T1, "ill");
        s.markUnacceptedWarned(T1);
        UUID replacement = UUID.randomUUID();

        s.reassignTo(replacement);

        assertThat(s.getWorkerId()).isEqualTo(replacement);
        assertThat(s.getConfirmedAt()).isNull();
        assertThat(s.getDeclinedAt()).isNull();
        assertThat(s.getDeclineReason()).isNull();
        assertThat(s.getUnacceptedWarnedAt()).isNull();
    }
}
