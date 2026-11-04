package com.zairo.factory.search;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.reviews.ProviderRatingSummary;
import com.zairo.factory.search.SearchDtos.ProviderSearchResult;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RatingComparatorTest {

    private static ProviderSearchResult provider(UUID id) {
        return new ProviderSearchResult(id, "p", "beauty", null, true, null, List.of(), null, null, null, null, null,
                null, null, null, null, null, java.util.Map.of());
    }

    private static List<UUID> sorted(Map<UUID, ProviderRatingSummary> ratings, UUID... ids) {
        List<ProviderSearchResult> results = new ArrayList<>();
        for (UUID id : ids) {
            results.add(provider(id));
        }
        results.sort(SearchService.ratingComparator(ratings));
        return results.stream().map(ProviderSearchResult::id).toList();
    }

    @Test
    void theBetterBayesianRatingWinsEvenWithALowerRawRating() {
        UUID established = UUID.randomUUID();
        UUID lone = UUID.randomUUID();
        // 3.9 smoothed beats 3.6 smoothed regardless of raw ratings (4.0 over 100 reviews vs 5.0 over 1).
        Map<UUID, ProviderRatingSummary> ratings = Map.of(established, new ProviderRatingSummary(4.0, 100, 3.9),
                lone, new ProviderRatingSummary(5.0, 1, 3.6));

        assertThat(sorted(ratings, lone, established)).containsExactly(established, lone);
    }

    @Test
    void aTieOnTheSmoothedRatingGoesToTheHigherRawRating() {
        UUID higherRaw = UUID.randomUUID();
        UUID lowerRaw = UUID.randomUUID();
        // Same smoothed score; this tie-break used to be ascending, so the lower raw rating won.
        Map<UUID, ProviderRatingSummary> ratings = Map.of(higherRaw, new ProviderRatingSummary(4.0, 25, 3.5),
                lowerRaw, new ProviderRatingSummary(3.75, 50, 3.5));

        assertThat(sorted(ratings, lowerRaw, higherRaw)).containsExactly(higherRaw, lowerRaw);
        assertThat(sorted(ratings, higherRaw, lowerRaw)).containsExactly(higherRaw, lowerRaw);
    }

    @Test
    void thenMoreReviewsThenTheIdForAStableOrder() {
        UUID few = new UUID(0, 1);
        UUID many = new UUID(0, 2);
        UUID tieA = new UUID(0, 3);
        UUID tieB = new UUID(0, 4);
        Map<UUID, ProviderRatingSummary> ratings = Map.of(
                few, new ProviderRatingSummary(4.0, 10, 3.5),
                many, new ProviderRatingSummary(4.0, 40, 3.5),
                tieA, new ProviderRatingSummary(4.0, 5, 3.5),
                tieB, new ProviderRatingSummary(4.0, 5, 3.5));

        assertThat(sorted(ratings, tieB, few, tieA, many)).containsExactly(many, few, tieA, tieB);
    }

    @Test
    void providersWithoutReviewsComeLast() {
        UUID rated = UUID.randomUUID();
        UUID unrated = UUID.randomUUID();
        Map<UUID, ProviderRatingSummary> ratings = Map.of(rated, new ProviderRatingSummary(1.0, 3, 2.0));

        assertThat(sorted(ratings, unrated, rated)).containsExactly(rated, unrated);
    }
}
