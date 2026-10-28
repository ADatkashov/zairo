package com.zairo.factory.search;

import com.zairo.factory.search.PopularServicesDtos.PopularService;
import java.math.BigDecimal;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Turns per-offering booking counts into "popular services": offerings with the same title (ignoring case and spacing)
 * and currency are one service, however many businesses offer it. Pure and static so the ranking rules are unit-tested
 * without a database.
 */
final class PopularServicesRanker {

    private PopularServicesRanker() {
    }

    /** One offering with the bookings it got. */
    record Candidate(String title, UUID providerId, BigDecimal price, String currency, long bookings) {
    }

    /**
     * Most bookings first; ties go to the service offered by more businesses, then to the title (so the order never
     * flickers between calls). Offerings with no bookings, blank titles or no price are not "popular" and are skipped.
     */
    static List<PopularService> rank(List<Candidate> candidates, int limit) {
        Map<String, Tally> byKey = new LinkedHashMap<>();
        for (Candidate c : candidates) {
            if (c.title() == null || c.title().isBlank() || c.bookings() <= 0 || c.price() == null) {
                continue;
            }
            String key = c.title().trim().toLowerCase(Locale.ROOT) + '|' + c.currency();
            Tally tally = byKey.computeIfAbsent(key, k -> new Tally(c.title().trim(), c.currency()));
            tally.bookings += c.bookings();
            tally.providers.add(c.providerId());
            if (c.price().compareTo(tally.minPrice) < 0) {
                tally.minPrice = c.price();
            }
            // The most booked offering names the service.
            if (c.bookings() > tally.topOfferingBookings) {
                tally.topOfferingBookings = c.bookings();
                tally.title = c.title().trim();
            }
        }
        return byKey.values().stream()
                .sorted(Comparator.comparingLong((Tally t) -> t.bookings).reversed()
                        .thenComparing(Comparator.comparingInt((Tally t) -> t.providers.size()).reversed())
                        .thenComparing(t -> t.title))
                .limit(Math.max(limit, 0))
                .map(t -> new PopularService(t.title, t.bookings, t.providers.size(), t.minPrice, t.currency))
                .toList();
    }

    private static final class Tally {
        String title;
        final String currency;
        long bookings;
        long topOfferingBookings;
        BigDecimal minPrice = new BigDecimal("999999999");
        final Set<UUID> providers = new HashSet<>();

        Tally(String title, String currency) {
            this.title = title;
            this.currency = currency;
        }
    }
}
