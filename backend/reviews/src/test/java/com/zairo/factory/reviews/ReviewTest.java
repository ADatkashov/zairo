package com.zairo.factory.reviews;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ReviewTest {

    private static final Instant NOW = Instant.parse("2026-10-15T10:00:00Z");

    @Test
    void withoutASeparateRatingTheOneRatingCountsForThePersonToo() {
        Review review = new Review(UUID.randomUUID(), UUID.randomUUID(), 4, "Fine", NOW);

        assertThat(review.getWorkerRating()).isNull();
        assertThat(review.getRatingForWorker()).isEqualTo(4);
    }

    @Test
    void aSeparateRatingOfThePersonCountsForThemAndNotForTheBusiness() {
        Review review = new Review(UUID.randomUUID(), UUID.randomUUID(), 5, 3, "Great salon, slow master", NOW);

        assertThat(review.getRating()).isEqualTo(5);
        assertThat(review.getWorkerRating()).isEqualTo(3);
        assertThat(review.getRatingForWorker()).isEqualTo(3);
    }
}
