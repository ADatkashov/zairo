package com.zairo.factory.search;

import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.search.SearchDtos.ProviderSearchResult;
import com.zairo.factory.search.SearchDtos.ServiceSummary;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Deterministic MVP ranking: open availability first, then distance (when
 * the caller supplies its own lat/lng and the provider has one), then
 * cheapest active service price. Rating is deliberately NOT part of the
 * ranking yet — it would need a live join across services -> bookings ->
 * reviews on every search request; worth a materialized read model once
 * search has real traffic, not a per-request join for an MVP with no data
 * yet.
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

    public SearchService(ProviderRepository providerRepository, ServiceOfferingRepository serviceOfferingRepository,
            AvailabilitySlotRepository availabilitySlotRepository) {
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    public List<ProviderSearchResult> search(String vertical, String query, Double originLat, Double originLng) {
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

        return providers.stream().map(p -> toResult(p, originLat, originLng))
                .sorted(Comparator.comparing(ProviderSearchResult::hasOpenAvailability).reversed()
                        .thenComparing(r -> r.distanceKm() == null ? Double.MAX_VALUE : r.distanceKm())
                        .thenComparing(r -> r.minPrice() == null ? BigDecimal.valueOf(Long.MAX_VALUE) : r.minPrice()))
                .toList();
    }

    private ProviderSearchResult toResult(Provider provider, Double originLat, Double originLng) {
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

        return new ProviderSearchResult(provider.getId(), provider.getName(), provider.getVertical(),
                provider.getStatus(), hasOpenAvailability, minPrice, serviceSummaries, distanceKm,
                provider.getLatitude(), provider.getLongitude());
    }
}
