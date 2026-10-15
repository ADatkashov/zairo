package com.zairo.factory.workforce;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.workforce.WorkerDirectoryDtos.TopWorkerResponse;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit tests of the pure parts of the worker directory -- no Spring context, no database. */
class WorkerDirectoryTest {

    @Test
    void limitIsClampedToOneThroughTwenty() {
        assertThat(WorkerDirectoryService.clampLimit(0)).isEqualTo(1);
        assertThat(WorkerDirectoryService.clampLimit(-5)).isEqualTo(1);
        assertThat(WorkerDirectoryService.clampLimit(10)).isEqualTo(10);
        assertThat(WorkerDirectoryService.clampLimit(1000)).isEqualTo(WorkerDirectoryService.MAX_TOP);
    }

    @Test
    void topResponseRoundsTheRatingToOneDecimalAndKeepsTheKind() {
        Worker worker = new Worker(WorkerKind.MASTER, UUID.randomUUID(), UUID.randomUUID(), null, "Aigerim",
                "https://img/1.png", true);

        TopWorkerResponse response = TopWorkerResponse.from(new WorkerCatalog.Ranked(worker, "Studio", 4.666666, 3));

        assertThat(response.averageRating()).isEqualTo(4.7);
        assertThat(response.reviewCount()).isEqualTo(3);
        assertThat(response.kind()).isEqualTo(WorkerKind.MASTER);
        assertThat(response.providerName()).isEqualTo("Studio");
        assertThat(response.displayName()).isEqualTo("Aigerim");
        assertThat(response.photoUrl()).isEqualTo("https://img/1.png");
    }
}
