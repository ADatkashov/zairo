package com.zairo.factory.search;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.reviews.ProviderRatingSummary;
import com.zairo.factory.reviews.ReviewSummaryService;
import com.zairo.factory.search.RecommendationsDtos.RecommendedProvider;
import com.zairo.factory.search.RecommendationsRanker.Candidate;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * "Recommended for you", learned from the customer's own bookings: the categories they book in, and businesses in
 * them they have not tried yet. Computed on request from Booking/ServiceOffering/Provider, same "read-only, no new
 * table" shape as {@link BookAgainService}. A customer with no kept bookings has nothing to learn from, so gets an
 * empty list (clients then show a generic best-rated list).
 */
@Service
public class RecommendationsService {

    static final int DEFAULT_LIMIT = 10;
    static final int MAX_LIMIT = 30;

    private final BookingRepository bookingRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderRepository providerRepository;
    private final ReviewSummaryService reviewSummaryService;

    public RecommendationsService(BookingRepository bookingRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderRepository providerRepository,
            ReviewSummaryService reviewSummaryService) {
        this.bookingRepository = bookingRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerRepository = providerRepository;
        this.reviewSummaryService = reviewSummaryService;
    }

    public List<RecommendedProvider> forUser(UUID userId, String cityCode, Integer limit) {
        List<Booking> kept = bookingRepository.findByUserId(userId).stream()
                .filter(b -> b.getStatus() == BookingStatus.COMPLETED || b.getStatus() == BookingStatus.CONFIRMED)
                .toList();
        if (kept.isEmpty()) {
            return List.of();
        }

        Map<UUID, ServiceOffering> offerings = serviceOfferingRepository
                .findAllById(kept.stream().map(Booking::getServiceId).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, Function.identity()));
        Map<UUID, Provider> visited = providerRepository
                .findAllById(offerings.values().stream().map(ServiceOffering::getProviderId).distinct().toList())
                .stream().collect(Collectors.toMap(Provider::getId, Function.identity()));

        Map<String, Integer> bookingsByVertical = new HashMap<>();
        for (Booking booking : kept) {
            ServiceOffering offering = offerings.get(booking.getServiceId());
            Provider provider = offering == null ? null : visited.get(offering.getProviderId());
            if (provider != null && provider.getVertical() != null) {
                bookingsByVertical.merge(provider.getVertical(), 1, Integer::sum);
            }
        }
        if (bookingsByVertical.isEmpty()) {
            return List.of();
        }

        String city = cityCode == null || cityCode.isBlank() ? null : cityCode.trim();
        List<Provider> pool = new java.util.ArrayList<>();
        for (String vertical : bookingsByVertical.keySet()) {
            pool.addAll(providerRepository.findByVerticalAndStatus(vertical, ProviderStatus.ACTIVE));
        }
        // Same city rule as search: that city's businesses plus those that have not set one yet.
        List<Provider> inCity = pool.stream()
                .filter(p -> city == null || p.getCityCode() == null || city.equals(p.getCityCode())).toList();
        Map<UUID, ProviderRatingSummary> ratings = reviewSummaryService
                .summarizeRatings(inCity.stream().map(Provider::getId).toList());
        List<Candidate> candidates = inCity.stream()
                .map(p -> new Candidate(p.getId(), p.getVertical(),
                        ratings.get(p.getId()) == null ? -1.0 : ratings.get(p.getId()).bayesianRating()))
                .toList();
        Set<UUID> visitedIds = new HashSet<>(visited.keySet());
        int size = limit == null ? DEFAULT_LIMIT : Math.min(Math.max(limit, 1), MAX_LIMIT);
        return RecommendationsRanker.rank(bookingsByVertical, visitedIds, candidates, size);
    }
}
