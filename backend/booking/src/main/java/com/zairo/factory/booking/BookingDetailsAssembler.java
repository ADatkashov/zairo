package com.zairo.factory.booking;

import com.zairo.factory.booking.BookingDtos.BookingResponse;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/**
 * Turns bookings into {@link BookingResponse}s that also say what was booked, with whom and when. A booking only
 * stores the ids of its service and slot, so a client listing bookings had nothing to show but prices and the
 * creation time. This resolves the slot, the service and the business in three batched lookups, however many
 * bookings there are (no query per booking). A reference that can no longer be resolved leaves its fields null
 * rather than failing the whole list.
 */
@Component
class BookingDetailsAssembler {

    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderRepository providerRepository;

    BookingDetailsAssembler(AvailabilitySlotRepository availabilitySlotRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderRepository providerRepository) {
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerRepository = providerRepository;
    }

    BookingResponse one(Booking booking) {
        return many(List.of(booking)).get(0);
    }

    /** One response per booking, in the order given. */
    List<BookingResponse> many(Collection<Booking> bookings) {
        if (bookings.isEmpty()) {
            return List.of();
        }
        Map<UUID, AvailabilitySlot> slots = availabilitySlotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        Map<UUID, ServiceOffering> services = serviceOfferingRepository
                .findAllById(bookings.stream().map(Booking::getServiceId).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, Function.identity()));
        // The slot is the authority on which business the appointment is with; the service's own
        // business is the fallback if the slot is gone.
        Set<UUID> providerIds = new HashSet<>();
        slots.values().forEach(slot -> providerIds.add(slot.getProviderId()));
        services.values().forEach(service -> providerIds.add(service.getProviderId()));
        Map<UUID, Provider> providers = providerRepository.findAllById(providerIds).stream()
                .collect(Collectors.toMap(Provider::getId, Function.identity()));

        return bookings.stream().map(booking -> {
            AvailabilitySlot slot = slots.get(booking.getAvailabilitySlotId());
            ServiceOffering service = services.get(booking.getServiceId());
            UUID providerId = slot != null ? slot.getProviderId() : service != null ? service.getProviderId() : null;
            Provider provider = providerId == null ? null : providers.get(providerId);
            return BookingResponse.from(booking, new BookingResponse.Details(
                    service == null ? null : service.getTitle(),
                    provider == null ? null : provider.getId(),
                    provider == null ? null : provider.getName(),
                    provider == null ? null : provider.getVertical(),
                    slot == null ? null : slot.getStartsAt(),
                    slot == null ? null : slot.getEndsAt()));
        }).toList();
    }
}
