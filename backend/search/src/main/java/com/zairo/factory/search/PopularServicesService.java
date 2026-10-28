package com.zairo.factory.search;

import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingRepository.ServiceBookingCountRow;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.search.PopularServicesDtos.PopularService;
import com.zairo.factory.search.PopularServicesRanker.Candidate;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * "Most booked services" for Home: real bookings of the last {@link #WINDOW_DAYS} days, per service name, optionally
 * for one city. Only active offerings of ACTIVE businesses count, so nothing a customer cannot book is advertised. On a
 * young platform this is short or empty; callers fall back to what the search results offer.
 */
@Service
public class PopularServicesService {

    static final int WINDOW_DAYS = 90;
    static final int DEFAULT_LIMIT = 8;
    static final int MAX_LIMIT = 20;

    private final BookingRepository bookingRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderRepository providerRepository;

    public PopularServicesService(BookingRepository bookingRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderRepository providerRepository) {
        this.bookingRepository = bookingRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerRepository = providerRepository;
    }

    public List<PopularService> popular(String cityCode, Integer limit) {
        String city = cityCode == null || cityCode.isBlank() ? null : cityCode.trim();
        List<ServiceBookingCountRow> rows = bookingRepository
                .countBookingsPerService(Instant.now().minus(Duration.ofDays(WINDOW_DAYS)), city);
        if (rows.isEmpty()) {
            return List.of();
        }
        Map<UUID, Long> bookingsByService = rows.stream()
                .collect(Collectors.toMap(ServiceBookingCountRow::getServiceId, ServiceBookingCountRow::getBookings));
        Map<UUID, ServiceOffering> offerings = serviceOfferingRepository.findAllById(bookingsByService.keySet())
                .stream().filter(ServiceOffering::isActive)
                .collect(Collectors.toMap(ServiceOffering::getId, Function.identity()));
        Set<UUID> activeProviders = providerRepository
                .findAllById(offerings.values().stream().map(ServiceOffering::getProviderId).distinct().toList())
                .stream().filter(p -> p.getStatus() == ProviderStatus.ACTIVE).map(Provider::getId)
                .collect(Collectors.toSet());

        List<Candidate> candidates = offerings.values().stream()
                .filter(o -> activeProviders.contains(o.getProviderId()))
                .map(o -> new Candidate(o.getTitle(), o.getProviderId(), o.getPrice(), o.getCurrency(),
                        bookingsByService.get(o.getId())))
                .toList();
        int size = limit == null ? DEFAULT_LIMIT : Math.min(Math.max(limit, 1), MAX_LIMIT);
        return PopularServicesRanker.rank(candidates, size);
    }
}
