package com.zairo.factory.workforce;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Records a worker's "I can't attend" in its own short transaction (so what follows can see it committed). */
@Component
class WorkerDeclineRecorder {

    /** What was recorded: whether this was the first request, and whether the customer didn't mind who serves them. */
    record Recorded(boolean first, boolean customerDidntMind) {
    }

    private final WorkerBookingStateRepository stateRepository;

    WorkerDeclineRecorder(WorkerBookingStateRepository stateRepository) {
        this.stateRepository = stateRepository;
    }

    @Transactional
    Recorded record(UUID bookingId, Worker worker, String reason) {
        WorkerBookingState state = stateRepository.findById(bookingId).orElseGet(
                () -> new WorkerBookingState(bookingId, worker.id(), WorkerBookingState.Preference.SPECIFIC,
                        Instant.now()));
        boolean first = state.getDeclinedAt() == null;
        state.requestDecline(Instant.now(), reason);
        stateRepository.save(state);
        return new Recorded(first, state.getPreference() == WorkerBookingState.Preference.ANY);
    }
}
