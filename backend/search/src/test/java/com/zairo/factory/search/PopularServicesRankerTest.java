package com.zairo.factory.search;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.search.PopularServicesDtos.PopularService;
import com.zairo.factory.search.PopularServicesRanker.Candidate;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PopularServicesRankerTest {

    private static final UUID A = UUID.randomUUID();
    private static final UUID B = UUID.randomUUID();
    private static final UUID C = UUID.randomUUID();

    private static Candidate offer(String title, UUID provider, String price, long bookings) {
        return new Candidate(title, provider, new BigDecimal(price), "KZT", bookings);
    }

    @Test
    void noCandidatesMeansNoPopularServices() {
        assertThat(PopularServicesRanker.rank(List.of(), 8)).isEmpty();
    }

    @Test
    void sameNameAcrossBusinessesIsOneServiceWithSummedBookingsAndTheLowestPrice() {
        List<PopularService> result = PopularServicesRanker.rank(List.of(
                offer("Haircut", A, "5000", 10), offer(" haircut ", B, "4000", 7), offer("Manicure", C, "3500", 12)),
                8);

        assertThat(result).extracting(PopularService::title).containsExactly("Haircut", "Manicure");
        PopularService haircut = result.get(0);
        assertThat(haircut.bookings()).isEqualTo(17);
        assertThat(haircut.providerCount()).isEqualTo(2);
        assertThat(haircut.minPrice()).isEqualByComparingTo("4000");
        assertThat(haircut.currency()).isEqualTo("KZT");
    }

    @Test
    void theMostBookedOfferingNamesTheService() {
        List<PopularService> result = PopularServicesRanker.rank(
                List.of(offer("haircut", A, "5000", 2), offer("Haircut", B, "5000", 9)), 8);

        assertThat(result.get(0).title()).isEqualTo("Haircut");
    }

    @Test
    void tiesGoToTheServiceMoreBusinessesOfferThenToTheTitle() {
        List<PopularService> result = PopularServicesRanker.rank(List.of(
                offer("Zeta", A, "1000", 5), offer("Beta", A, "1000", 5), offer("Beta", B, "1000", 0),
                offer("Alpha", A, "1000", 3), offer("Alpha", B, "1000", 2)), 8);

        // Alpha: 5 bookings, 2 businesses; Beta and Zeta: 5 bookings, 1 business each.
        assertThat(result).extracting(PopularService::title).containsExactly("Alpha", "Beta", "Zeta");
    }

    @Test
    void servicesWithNoBookingsBlankTitleOrNoPriceAreNotPopular() {
        List<PopularService> result = PopularServicesRanker.rank(List.of(
                offer("Unbooked", A, "1000", 0), offer("  ", A, "1000", 5),
                new Candidate("No price", A, null, "KZT", 5), new Candidate(null, A, BigDecimal.ONE, "KZT", 5)), 8);

        assertThat(result).isEmpty();
    }

    @Test
    void differentCurrenciesAreDifferentServices() {
        List<PopularService> result = PopularServicesRanker.rank(List.of(
                new Candidate("Haircut", A, new BigDecimal("5000"), "KZT", 3),
                new Candidate("Haircut", B, new BigDecimal("12"), "USD", 2)), 8);

        assertThat(result).extracting(PopularService::currency).containsExactly("KZT", "USD");
    }

    @Test
    void theListIsCappedAtTheLimit() {
        List<Candidate> many = new java.util.ArrayList<>();
        for (int i = 0; i < 12; i++) {
            many.add(offer("Service " + i, A, "1000", 100 - i));
        }

        assertThat(PopularServicesRanker.rank(many, 5)).hasSize(5);
        assertThat(PopularServicesRanker.rank(many, 0)).isEmpty();
    }
}
