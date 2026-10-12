package com.zairo.factory.reviews;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;

class ReviewSummaryDistributionTest {

    private static ReviewRepository.RatingCountRow row(int rating, long total) {
        return new ReviewRepository.RatingCountRow() {
            public int getRating() {
                return rating;
            }

            public long getTotal() {
                return total;
            }
        };
    }

    @Test
    void noReviewsHasNullAverageAndFiveZeroBuckets() {
        var summary = ReviewService.summarize(List.of());
        assertThat(summary.total()).isZero();
        assertThat(summary.average()).isNull();
        assertThat(summary.distribution()).containsExactly(0L, 0L, 0L, 0L, 0L);
    }

    @Test
    void fillsMissingStarsAndRoundsAverageToOneDecimal() {
        // (1*1 + 3*4 + 6*5) / 10 = 4.3
        var summary = ReviewService.summarize(List.of(row(5, 6), row(4, 3), row(1, 1)));
        assertThat(summary.total()).isEqualTo(10);
        assertThat(summary.average()).isEqualTo(4.3);
        assertThat(summary.distribution()).containsExactly(1L, 0L, 0L, 3L, 6L);
    }

    @Test
    void ignoresOutOfRangeRatings() {
        var summary = ReviewService.summarize(List.of(row(9, 5), row(5, 1)));
        assertThat(summary.total()).isEqualTo(1);
        assertThat(summary.average()).isEqualTo(5.0);
    }

    @Test
    void sortDefaultsToNewestAndRejectsUnknownValues() {
        assertThat(ReviewService.normalizeSort(null)).isEqualTo("newest");
        assertThat(ReviewService.normalizeSort(" HIGHEST ")).isEqualTo("highest");
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> ReviewService.normalizeSort("random"))
                .isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
    }
}
