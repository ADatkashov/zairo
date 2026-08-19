package com.zairo.factory.search;

import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
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
 * Deterministic MVP ranking: open availability first, then cheapest active
 * service price. Rating is deliberately NOT part of the ranking yet — it
 * would need a live join across services -> bookings -> reviews on every
 * search request; worth a materialized read model once search has real
 * traffic, not a per-request join for an MVP with no data yet. Distance is
 * out of scope until providers carry location data (see Factory Blueprint
 * §19 — maps/geo deferred).
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

    public List<ProviderSearchResult> search(String vertical, String query) {
        List<Provider> providers = vertical == null || vertical.isBlank() ? providerRepository.findAll()
                : providerRepository.findByVertical(vertical);

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

        return providers.stream().map(this::toResult)
                .sorted(Comparator.comparing(ProviderSearchResult::hasOpenAvailability).reversed()
                        .thenComparing(r -> r.minPrice() == null ? BigDecimal.valueOf(Long.MAX_VALUE) : r.minPrice()))
                .toList();
    }

    private ProviderSearchResult toResult(Provider provider) {
        List<ServiceOffering> services = serviceOfferingRepository.findByProviderIdAndActiveTrue(provider.getId());
        boolean hasOpenAvailability = availabilitySlotRepository.existsByProviderIdAndStatus(provider.getId(),
                AvailabilityStatus.OPEN);
        BigDecimal minPrice = services.stream().map(ServiceOffering::getPrice).min(Comparator.naturalOrder())
                .orElse(null);
        List<ServiceSummary> serviceSummaries = services.stream()
                .map(s -> new ServiceSummary(s.getId(), s.getTitle(), s.getDurationMinutes(), s.getPrice(),
                        s.getCurrency()))
                .toList();
        return new ProviderSearchResult(provider.getId(), provider.getName(), provider.getVertical(),
                provider.getStatus(), hasOpenAvailability, minPrice, serviceSummaries);
    }
}
