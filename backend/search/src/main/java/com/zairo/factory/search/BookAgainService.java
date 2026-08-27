package com.zairo.factory.search;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.search.BookAgainDtos.BookAgainSuggestion;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * "Repeat your last appointment" — one row per distinct service the
 * customer has completed a booking for, newest visit first, capped at
 * {@link #MAX_SUGGESTIONS}. Computed fresh from Booking/AvailabilitySlot/
 * ServiceOffering/Provider on every call, same "read-only, no new table"
 * shape as provider-insights' customer history — this codebase's cheapest
 * correct answer until it's ever actually slow (see the discovery ADR's
 * performance section).
 */
@Service
public class BookAgainService {

    private static final int MAX_SUGGESTIONS = 5;

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderRepository providerRepository;

    public BookAgainService(BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderRepository providerRepository) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerRepository = providerRepository;
    }

    public List<BookAgainSuggestion> suggestionsForUser(UUID userId) {
        List<Booking> completed = bookingRepository.findByUserId(userId).stream()
                .filter(b -> b.getStatus() == BookingStatus.COMPLETED).toList();
        if (completed.isEmpty()) {
            return List.of();
        }

        Map<UUID, Instant> slotStartsAtBySlotId = availabilitySlotRepository
                .findAllById(completed.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, AvailabilitySlot::getStartsAt));

        // One suggestion per distinct service — the most recent completed
        // visit for each, not every past visit.
        Map<UUID, Booking> mostRecentByServiceId = completed.stream().collect(Collectors.toMap(Booking::getServiceId,
                b -> b, (a, b) -> visitedAt(a, slotStartsAtBySlotId).isAfter(visitedAt(b, slotStartsAtBySlotId))
                        ? a : b));

        List<Booking> topRecent = mostRecentByServiceId.values().stream()
                .sorted(Comparator.comparing((Booking b) -> visitedAt(b, slotStartsAtBySlotId)).reversed())
                .limit(MAX_SUGGESTIONS).toList();

        Map<UUID, ServiceOffering> serviceById = serviceOfferingRepository
                .findAllById(topRecent.stream().map(Booking::getServiceId).toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, s -> s));
        Map<UUID, Provider> providerById = providerRepository
                .findAllById(serviceById.values().stream().map(ServiceOffering::getProviderId).distinct().toList())
                .stream().collect(Collectors.toMap(Provider::getId, p -> p));

        return topRecent.stream()
                .map(b -> toSuggestion(b, serviceById.get(b.getServiceId()), providerById, slotStartsAtBySlotId))
                .filter(Objects::nonNull)
                .toList();
    }

    private Instant visitedAt(Booking booking, Map<UUID, Instant> slotStartsAtBySlotId) {
        Instant slotStart = slotStartsAtBySlotId.get(booking.getAvailabilitySlotId());
        return slotStart != null ? slotStart : booking.getCreatedAt();
    }

    private BookAgainSuggestion toSuggestion(Booking booking, ServiceOffering service, Map<UUID, Provider> providerById,
            Map<UUID, Instant> slotStartsAtBySlotId) {
        // The service (or its provider) may since have been deactivated/
        // removed — skip rather than surface a suggestion the customer
        // can't act on, same "absent means unavailable" reasoning used
        // elsewhere (see e.g. ReviewRepository's own doc comment).
        if (service == null) {
            return null;
        }
        Provider provider = providerById.get(service.getProviderId());
        if (provider == null) {
            return null;
        }
        return new BookAgainSuggestion(provider.getId(), provider.getName(), provider.getVertical(), service.getId(),
                service.getTitle(), service.getDurationMinutes(), service.getPrice(), service.getCurrency(),
                visitedAt(booking, slotStartsAtBySlotId));
    }
}
