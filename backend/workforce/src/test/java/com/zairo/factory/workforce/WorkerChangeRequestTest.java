package com.zairo.factory.workforce;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class WorkerChangeRequestTest {

    private static final Instant CREATED = Instant.parse("2026-10-12T09:00:00Z");
    private static final Instant FIRST = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant LATER = Instant.parse("2026-10-12T11:00:00Z");

    private static WorkerChangeRequest open() {
        return new WorkerChangeRequest(UUID.randomUUID(), UUID.randomUUID(), "sick", CREATED);
    }

    @Test
    void newRequestIsOpenWithoutAResolution() {
        WorkerChangeRequest r = open();

        assertThat(r.getStatus()).isEqualTo(WorkerChangeRequest.Status.OPEN);
        assertThat(r.getResolution()).isNull();
        assertThat(r.getResolvedAt()).isNull();
        assertThat(r.getReason()).isEqualTo("sick");
        assertThat(r.getCreatedAt()).isEqualTo(CREATED);
    }

    @Test
    void resolvingRecordsHowAndWhen() {
        WorkerChangeRequest r = open();

        r.resolve(WorkerChangeRequest.Resolution.REPLACED, FIRST);

        assertThat(r.getStatus()).isEqualTo(WorkerChangeRequest.Status.RESOLVED);
        assertThat(r.getResolution()).isEqualTo(WorkerChangeRequest.Resolution.REPLACED);
        assertThat(r.getResolvedAt()).isEqualTo(FIRST);
    }

    @Test
    void aResolvedRequestKeepsItsFirstResolution() {
        WorkerChangeRequest r = open();
        r.resolve(WorkerChangeRequest.Resolution.MOVED, FIRST);

        r.resolve(WorkerChangeRequest.Resolution.CANCELLED, LATER);

        assertThat(r.getResolution()).isEqualTo(WorkerChangeRequest.Resolution.MOVED);
        assertThat(r.getResolvedAt()).isEqualTo(FIRST);
    }
}
