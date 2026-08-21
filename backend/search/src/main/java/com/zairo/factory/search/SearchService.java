package com.zairo.factory.search;

import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.reviews.ProviderRatingSummary;
import com.zairo.factory.reviews.ReviewSummaryService;
import com.zairo.factory.search.SearchDtos.ProviderSearchResult;
import com.zairo.factory.search.SearchDtos.ServiceSummary;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Deterministic MVP ranking: open availability first, then distance (when
 * the caller supplies its own lat/lng and the provider has one), then
 * cheapest active service price — unchanged as the RECOMMENDED default;
 * rating is available as an explicit opt-in sort/filter instead of folded
 * into the default ranking, since a provider with one 5-star review
 * shouldn't outrank an established one with a real track record just by
 * having a higher average.
 *
 * Rating comes from {@link ReviewSummaryService}, one batched query for
 * every candidate provider in this request — see its doc comment for why
 * that isn't a per-provider join.
 *
 * Distance itself is just Haversine math (see DistanceCalculator) — no
 * external geo service needed. What's still genuinely deferred is
 * geocoding (turning a typed address into lat/lng) and real map
 * rendering, both of which need an external provider account; see
 * apps/user_app/lib/features/maps/ for the mocked client-side stand-in.
 */
@Service
public class SearchService {

    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ReviewSummaryService reviewSummaryService;

    public SearchService(ProviderRepository providerRepository, ServiceOfferingRepository serviceOfferingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ReviewSummaryService reviewSummaryService) {
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.reviewSummaryService = reviewSummaryService;
    }

    /**
     * {@code minPrice}/{@code maxPrice} filter on a provider's cheapest
     * active service (the same {@code minPrice} already shown on the
     * result); a provider with no active services (minPrice null) never
     * matches either bound, same reasoning as {@code maxDistanceKm} and
     * {@code minRating} below. {@code maxDistanceKm} only ever matches a
     * result with a known distance — meaningless without the caller also
     * supplying its own {@code originLat}/{@code originLng}, not enforced
     * as a hard error, it just filters everything out (a provider with no
     * distance can't prove it's within range). {@code minRating} excludes
     * providers with no reviews yet, same reasoning. {@code availableOnly}
     * filters to {@code hasOpenAvailability}.
     */
    public List<ProviderSearchResult> search(String vertical, String query, Double originLat, Double originLng,
            BigDecimal minPrice, BigDecimal maxPrice, Double maxDistanceKm, Double minRating, boolean availableOnly,
            SearchSort sort) {
        // Only ACTIVE providers are ever discoverable through search — a
        // PENDING (not yet moderated) or SUSPENDED provider still exists and
        // can be fetched directly by id, it's just invisible to browsing.
        // See ProviderController.updateStatus for the only way in/out of
        // ACTIVE.
        List<Provider> providers = vertical == null || vertical.isBlank()
                ? providerRepository.findByStatus(ProviderStatus.ACTIVE)
                : providerRepository.findByVerticalAndStatus(vertical, ProviderStatus.ACTIVE);

        if (query != null && !query.isBlank()) {
            String needle = query.toLowerCase();
            Set<UUID> providerIdsWithMatchingService = serviceOfferingRepository
                    .findByTitleContainingIgnoreCaseAndActiveTrue(query).stream().map(ServiceOffering::getProviderId)
                    .collect(Collectors.toSet());
            providers = providers.stream()
                    .filter(p -> p.getName().toLowerCase().contains(needle)
                            || providerIdsWithMatchingService.contains(p.getId()))
                    .toList();
        }

        Map<UUID, ProviderRatingSummary> ratings = reviewSummaryService
                .summarizeRatings(providers.stream().map(Provider::getId).toList());

        List<ProviderSearchResult> results = providers.stream().map(p -> toResult(p, originLat, originLng, ratings))
                .filter(r -> minPrice == null || (r.minPrice() != null && r.minPrice().compareTo(minPrice) >= 0))
                .filter(r -> maxPrice == null || (r.minPrice() != null && r.minPrice().compareTo(maxPrice) <= 0))
                .filter(r -> maxDistanceKm == null || (r.distanceKm() != null && r.distanceKm() <= maxDistanceKm))
                .filter(r -> minRating == null || (r.averageRating() != null && r.averageRating() >= minRating))
                .filter(r -> !availableOnly || r.hasOpenAvailability())
                .toList();

        Comparator<ProviderSearchResult> comparator = switch (sort == null ? SearchSort.RECOMMENDED : sort) {
            case PRICE_ASC -> Comparator.comparing(
                    r -> r.minPrice() == null ? BigDecimal.valueOf(Long.MAX_VALUE) : r.minPrice());
            case PRICE_DESC -> Comparator
                    .comparing((ProviderSearchResult r) -> r.minPrice() == null ? BigDecimal.ZERO : r.minPrice())
                    .reversed();
            case DISTANCE ->
                Comparator.comparing(r -> r.distanceKm() == null ? Double.MAX_VALUE : r.distanceKm());
            // No reviews yet sorts last, not first/zero — see the class doc comment.
            case RATING -> Comparator
                    .comparing((ProviderSearchResult r) -> r.averageRating() == null ? -1.0 : r.averageRating())
                    .reversed();
            case RECOMMENDED -> Comparator.comparing(ProviderSearchResult::hasOpenAvailability).reversed()
                    .thenComparing(r -> r.distanceKm() == null ? Double.MAX_VALUE : r.distanceKm())
                    .thenComparing(r -> r.minPrice() == null ? BigDecimal.valueOf(Long.MAX_VALUE) : r.minPrice());
        };
        return results.stream().sorted(comparator).toList();
    }

    private ProviderSearchResult toResult(Provider provider, Double originLat, Double originLng,
            Map<UUID, ProviderRatingSummary> ratings) {
        List<ServiceOffering> services = serviceOfferingRepository.findByProviderIdAndActiveTrue(provider.getId());
        boolean hasOpenAvailability = availabilitySlotRepository.existsByProviderIdAndStatus(provider.getId(),
                AvailabilityStatus.OPEN);
        BigDecimal minPrice = services.stream().map(ServiceOffering::getPrice).min(Comparator.naturalOrder())
                .orElse(null);
        List<ServiceSummary> serviceSummaries = services.stream()
                .map(s -> new ServiceSummary(s.getId(), s.getTitle(), s.getDurationMinutes(), s.getPrice(),
                        s.getCurrency()))
                .toList();

        Double distanceKm = null;
        if (originLat != null && originLng != null && provider.getLatitude() != null
                && provider.getLongitude() != null) {
            distanceKm = DistanceCalculator.distanceKm(originLat, originLng, provider.getLatitude(),
                    provider.getLongitude());
        }

        ProviderRatingSummary rating = ratings.get(provider.getId());

        return new ProviderSearchResult(provider.getId(), provider.getName(), provider.getVertical(),
                provider.getStatus(), hasOpenAvailability, minPrice, serviceSummaries, distanceKm,
                provider.getLatitude(), provider.getLongitude(), rating == null ? null : rating.averageRating(),
                rating == null ? null : rating.reviewCount());
    }
}
