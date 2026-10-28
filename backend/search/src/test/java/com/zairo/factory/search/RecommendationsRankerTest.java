package com.zairo.factory.search;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.search.RecommendationsDtos.RecommendedProvider;
import com.zairo.factory.search.RecommendationsRanker.Candidate;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RecommendationsRankerTest {

    private static UUID id(int n) {
        return new UUID(0, n);
    }

    private static List<UUID> ids(List<RecommendedProvider> result) {
        return result.stream().map(RecommendedProvider::providerId).toList();
    }

    @Test
    void noHistoryMeansNothingToLearnFrom() {
        assertThat(RecommendationsRanker.rank(Map.of(), Set.of(), List.of(new Candidate(id(1), "beauty", 4.9)), 10))
                .isEmpty();
    }

    @Test
    void onlyCategoriesTheCustomerBookedInAreRecommended() {
        List<RecommendedProvider> result = RecommendationsRanker.rank(Map.of("beauty", 3), Set.of(),
                List.of(new Candidate(id(1), "beauty", 4.0), new Candidate(id(2), "auto", 5.0)), 10);

        assertThat(ids(result)).containsExactly(id(1));
        assertThat(result.get(0).vertical()).isEqualTo("beauty");
    }

    @Test
    void aBusinessTheyHaveAlreadyBeenToIsNotRecommended() {
        List<RecommendedProvider> result = RecommendationsRanker.rank(Map.of("beauty", 2), Set.of(id(1)),
                List.of(new Candidate(id(1), "beauty", 5.0), new Candidate(id(2), "beauty", 3.0)), 10);

        assertThat(ids(result)).containsExactly(id(2));
    }

    @Test
    void theCategoryTheyBookMostComesFirstEvenAgainstAHigherRating() {
        List<RecommendedProvider> result = RecommendationsRanker.rank(Map.of("beauty", 8, "auto", 2), Set.of(),
                List.of(new Candidate(id(1), "auto", 5.0), new Candidate(id(2), "beauty", 3.5)), 10);

        assertThat(ids(result)).containsExactly(id(2), id(1));
    }

    @Test
    void insideACategoryTheBetterRatedWinsAndAnUnratedOneComesLast() {
        List<RecommendedProvider> result = RecommendationsRanker.rank(Map.of("beauty", 4), Set.of(),
                List.of(new Candidate(id(1), "beauty", -1), new Candidate(id(2), "beauty", 4.2),
                        new Candidate(id(3), "beauty", 4.8)), 10);

        assertThat(ids(result)).containsExactly(id(3), id(2), id(1));
    }

    @Test
    void equalScoresKeepAStableOrderAndTheListIsCapped() {
        List<Candidate> same = List.of(new Candidate(id(3), "beauty", 4.0), new Candidate(id(1), "beauty", 4.0),
                new Candidate(id(2), "beauty", 4.0));

        assertThat(ids(RecommendationsRanker.rank(Map.of("beauty", 1), Set.of(), same, 10)))
                .containsExactly(id(1), id(2), id(3));
        assertThat(RecommendationsRanker.rank(Map.of("beauty", 1), Set.of(), same, 2)).hasSize(2);
        assertThat(RecommendationsRanker.rank(Map.of("beauty", 1), Set.of(), same, 0)).isEmpty();
    }
}
