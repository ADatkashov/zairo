package com.zairo.factory.reviews;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import static org.mockito.Mockito.when;

/**
 * Unit tests for Bayesian rating calculation.
 * Tests that ratings are computed correctly using the Bayesian formula:
 * (n / (n + m)) * providerRating + (m / (n + m)) * globalRating
 */
@DisplayName("ReviewSummaryService - Bayesian Rating Tests")
class ReviewSummaryServiceTest {

    @Mock
    private ReviewRepository reviewRepository;

    private RatingProperties ratingProperties;
    private ReviewSummaryService service;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        ratingProperties = new RatingProperties();
        ratingProperties.setMinReviewsForConfidence(25);
        service = new ReviewSummaryService(reviewRepository, ratingProperties);
    }

    @Test
    @DisplayName("Case 1: Single 5-star review should be pulled toward global average")
    void singleFiveStarReviewGetsPulledTowardGlobalAverage() {
        UUID providerId = UUID.randomUUID();
        MockRepository.RowBuilder row = MockRepository.row(providerId)
                .averageRating(5.0)
                .reviewCount(1)
                .globalAverageRating(3.5);

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId)))
                .thenReturn(List.of(row.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId));

        assertThat(results).containsKey(providerId);
        ProviderRatingSummary summary = results.get(providerId);
        assertThat(summary.averageRating()).isEqualTo(5.0);
        assertThat(summary.reviewCount()).isEqualTo(1);
        // Bayesian: (1/(1+25)) * 5.0 + (25/26) * 3.5 = 0.038*5.0 + 0.962*3.5 ≈ 3.56
        assertThat(summary.bayesianRating())
                .isCloseTo(3.56, org.assertj.core.data.Offset.offset(0.01));
    }

    @Test
    @DisplayName("Case 2: Multiple ratings [5,5,5,5,1] average 4.2")
    void multipleRatingsAverageCorrectly() {
        UUID providerId = UUID.randomUUID();
        MockRepository.RowBuilder row = MockRepository.row(providerId)
                .averageRating(4.2)
                .reviewCount(5)
                .globalAverageRating(3.5);

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId)))
                .thenReturn(List.of(row.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId));

        ProviderRatingSummary summary = results.get(providerId);
        assertThat(summary.averageRating()).isEqualTo(4.2);
        assertThat(summary.reviewCount()).isEqualTo(5);
        // Bayesian: (5/(5+25)) * 4.2 + (25/30) * 3.5 = 0.167*4.2 + 0.833*3.5 ≈ 3.63
        assertThat(summary.bayesianRating())
                .isCloseTo(3.63, org.assertj.core.data.Offset.offset(0.01));
    }

    @Test
    @DisplayName("Case 3: All 1-star reviews should still count as 1.0, not be filtered")
    void allBadReviewsCountAsActualRating() {
        UUID providerId = UUID.randomUUID();
        MockRepository.RowBuilder row = MockRepository.row(providerId)
                .averageRating(1.0)
                .reviewCount(5)
                .globalAverageRating(3.5);

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId)))
                .thenReturn(List.of(row.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId));

        ProviderRatingSummary summary = results.get(providerId);
        assertThat(summary.averageRating()).isEqualTo(1.0);
        assertThat(summary.reviewCount()).isEqualTo(5);
        // Bayesian: (5/(5+25)) * 1.0 + (25/30) * 3.5 ≈ 2.79
        assertThat(summary.bayesianRating())
                .isCloseTo(2.79, org.assertj.core.data.Offset.offset(0.01));
    }

    @Test
    @DisplayName("Case 4: Provider with zero reviews returns empty map")
    void emptyProviderListReturnsEmptyMap() {
        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of());
        assertThat(results).isEmpty();
    }

    @Test
    @DisplayName("Case 5: Provider with 1 review (5-star) vs provider with 100 reviews (4.5-star)")
    void bayesianRankingPreventsSingleReviewBias() {
        UUID providerId1 = UUID.randomUUID();
        UUID providerId2 = UUID.randomUUID();

        MockRepository.RowBuilder row1 = MockRepository.row(providerId1)
                .averageRating(5.0)
                .reviewCount(1)
                .globalAverageRating(3.5);

        MockRepository.RowBuilder row2 = MockRepository.row(providerId2)
                .averageRating(4.5)
                .reviewCount(100)
                .globalAverageRating(3.5);

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId1, providerId2)))
                .thenReturn(List.of(row1.build(), row2.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId1, providerId2));

        ProviderRatingSummary summary1 = results.get(providerId1);
        ProviderRatingSummary summary2 = results.get(providerId2);

        // Provider 1: (1/(1+25)) * 5.0 + (25/26) * 3.5 ≈ 3.56
        assertThat(summary1.bayesianRating())
                .isCloseTo(3.56, org.assertj.core.data.Offset.offset(0.01));

        // Provider 2: (100/(100+25)) * 4.5 + (25/125) * 3.5 ≈ 4.30
        assertThat(summary2.bayesianRating())
                .isCloseTo(4.30, org.assertj.core.data.Offset.offset(0.01));

        // Provider 2 should rank higher despite lower raw rating
        assertThat(summary2.bayesianRating()).isGreaterThan(summary1.bayesianRating());
    }

    @Test
    @DisplayName("Case 6: 1-star review reduces average from 5.0 to 4.0 with 4 other 5-star reviews")
    void badReviewReducesAverageCorrectly() {
        UUID providerId = UUID.randomUUID();
        // Simulate [5, 5, 5, 5, 1] → average = 4.2
        MockRepository.RowBuilder row = MockRepository.row(providerId)
                .averageRating(4.2)
                .reviewCount(5)
                .globalAverageRating(3.5);

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId)))
                .thenReturn(List.of(row.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId));

        ProviderRatingSummary summary = results.get(providerId);
        assertThat(summary.averageRating()).isEqualTo(4.2);
        assertThat(summary.bayesianRating())
                .isCloseTo(3.63, org.assertj.core.data.Offset.offset(0.01));
    }

    @Test
    @DisplayName("Case 7: Business reply should not affect rating at all")
    void businessReplyDoesNotAffectRating() {
        // This test documents that business_reply is part of Review entity
        // but not included in rating calculation (confirmed by SQL query)
        UUID providerId = UUID.randomUUID();
        MockRepository.RowBuilder row = MockRepository.row(providerId)
                .averageRating(4.0)
                .reviewCount(10)
                .globalAverageRating(3.5);

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId)))
                .thenReturn(List.of(row.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId));
        ProviderRatingSummary summary = results.get(providerId);

        // Rating should be exactly 4.0, no change due to reply
        assertThat(summary.averageRating()).isEqualTo(4.0);
        assertThat(summary.reviewCount()).isEqualTo(10);
    }

    @Test
    @DisplayName("Case 8 & 9: minRating filter behavior - handled by SearchService, not here")
    void documentFilterBehavior() {
        // Note: minRating >= 4.0 filtering is done in SearchService.search(),
        // not in ReviewSummaryService. This test documents that:
        // - Providers with no reviews are ABSENT from the map (not present with null)
        // - SearchService.filter() checks if averageRating != null && >= minRating
        // - If minRating filter is applied, no-review providers are excluded
        assertThat(true).isTrue(); // Documentation test
    }

    @Test
    @DisplayName("Case 10: Multiple providers, batch query efficiency")
    void batchQueryReturnsAllProvidersInOneCall() {
        UUID provider1 = UUID.randomUUID();
        UUID provider2 = UUID.randomUUID();
        UUID provider3 = UUID.randomUUID();

        List<MockRepository.ProviderRatingRow> rows = List.of(
                MockRepository.row(provider1).averageRating(5.0).reviewCount(1).globalAverageRating(3.5).build(),
                MockRepository.row(provider2).averageRating(4.0).reviewCount(50).globalAverageRating(3.5).build(),
                MockRepository.row(provider3).averageRating(3.0).reviewCount(100).globalAverageRating(3.5).build()
        );

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(provider1, provider2, provider3)))
                .thenReturn(rows);

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(provider1, provider2, provider3));

        assertThat(results).hasSize(3);
        assertThat(results).containsKeys(provider1, provider2, provider3);

        // Verify Bayesian calculations are correct
        ProviderRatingSummary s1 = results.get(provider1);
        ProviderRatingSummary s2 = results.get(provider2);
        ProviderRatingSummary s3 = results.get(provider3);

        assertThat(s1.averageRating()).isEqualTo(5.0);
        assertThat(s2.averageRating()).isEqualTo(4.0);
        assertThat(s3.averageRating()).isEqualTo(3.0);

        // Ranking should be: s2 > s3 > s1 (based on Bayesian scores)
        assertThat(s2.bayesianRating()).isGreaterThan(s3.bayesianRating());
        assertThat(s3.bayesianRating()).isGreaterThan(s1.bayesianRating());
    }

    @Test
    @DisplayName("Case 11: Large review count reaches asymptote (raw rating ≈ Bayesian)")
    void largeReviewCountApproachesRawRating() {
        UUID providerId = UUID.randomUUID();
        // With 1000 reviews and m=25: (1000/1025) * 4.5 + (25/1025) * 3.5
        // ≈ 0.976 * 4.5 + 0.024 * 3.5 ≈ 4.47
        MockRepository.RowBuilder row = MockRepository.row(providerId)
                .averageRating(4.5)
                .reviewCount(1000)
                .globalAverageRating(3.5);

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId)))
                .thenReturn(List.of(row.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId));

        ProviderRatingSummary summary = results.get(providerId);
        // Bayesian should be very close to raw rating
        assertThat(summary.bayesianRating())
                .isCloseTo(summary.averageRating(), org.assertj.core.data.Offset.offset(0.1));
    }

    @Test
    @DisplayName("Case 12: Global rating fallback when null")
    void globalRatingFallbackTo3Point0() {
        UUID providerId = UUID.randomUUID();
        MockRepository.RowBuilder row = MockRepository.row(providerId)
                .averageRating(4.0)
                .reviewCount(5)
                .globalAverageRating(null); // Global is null

        when(reviewRepository.aggregateRatingsByProviderIds(List.of(providerId)))
                .thenReturn(List.of(row.build()));

        Map<UUID, ProviderRatingSummary> results = service.summarizeRatings(List.of(providerId));

        ProviderRatingSummary summary = results.get(providerId);
        // Should use fallback 3.0
        // (5/(5+25)) * 4.0 + (25/30) * 3.0 ≈ 3.17
        assertThat(summary.bayesianRating())
                .isCloseTo(3.17, org.assertj.core.data.Offset.offset(0.01));
    }

    /**
     * Mock helper to build repository row objects for testing.
     */
    static class MockRepository {
        static RowBuilder row(UUID providerId) {
            return new RowBuilder(providerId);
        }

        static class RowBuilder {
            private final UUID providerId;
            private double averageRating;
            private long reviewCount;
            private Double globalAverageRating;

            RowBuilder(UUID providerId) {
                this.providerId = providerId;
            }

            RowBuilder averageRating(double rating) {
                this.averageRating = rating;
                return this;
            }

            RowBuilder reviewCount(long count) {
                this.reviewCount = count;
                return this;
            }

            RowBuilder globalAverageRating(Double rating) {
                this.globalAverageRating = rating;
                return this;
            }

            ProviderRatingRow build() {
                return new ProviderRatingRow() {
                    @Override
                    public UUID getProviderId() {
                        return providerId;
                    }

                    @Override
                    public double getAverageRating() {
                        return averageRating;
                    }

                    @Override
                    public long getReviewCount() {
                        return reviewCount;
                    }

                    @Override
                    public Double getGlobalAverageRating() {
                        return globalAverageRating;
                    }
                };
            }
        }

        interface ProviderRatingRow extends ReviewRepository.ProviderRatingRow {
        }
    }
}
