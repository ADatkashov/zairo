package com.zairo.factory.booking;

import com.zairo.factory.booking.BookingDtos.BookingResponse;
import com.zairo.factory.booking.BookingDtos.ProviderRef;
import com.zairo.factory.booking.BookingDtos.SlotTimes;
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
import org.springframework.transaction.annotation.Transactional;

/**
 * Read-side join that turns bookings into {@link BookingResponse}s carrying
 * what a customer needs to recognise them: the service title, the business
 * and the appointment time. A booking only references its service and slot
 * by id, so this batches three lookups (slots, services, providers) for the
 * whole list instead of querying per booking.
 */
@Component
public class BookingResponseAssembler {

    private final AvailabilitySlotRepository slotRepository;
    private final ServiceOfferingRepository serviceRepository;
    private final ProviderRepository providerRepository;

    public BookingResponseAssembler(AvailabilitySlotRepository slotRepository,
            ServiceOfferingRepository serviceRepository, ProviderRepository providerRepository) {
        this.slotRepository = slotRepository;
        this.serviceRepository = serviceRepository;
        this.providerRepository = providerRepository;
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> assemble(Collection<Booking> bookings) {
        if (bookings.isEmpty()) {
            return List.of();
        }
        Set<UUID> slotIds = new HashSet<>();
        Set<UUID> serviceIds = new HashSet<>();
        for (Booking b : bookings) {
            slotIds.add(b.getAvailabilitySlotId());
            serviceIds.add(b.getServiceId());
        }
        Map<UUID, AvailabilitySlot> slots = slotRepository.findAllById(slotIds).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        Map<UUID, ServiceOffering> services = serviceRepository.findAllById(serviceIds).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, Function.identity()));

        // The slot is the authority on which business the appointment is with;
        // fall back to the service's provider if the slot is gone.
        Set<UUID> providerIds = new HashSet<>();
        slots.values().forEach(s -> providerIds.add(s.getProviderId()));
        services.values().forEach(s -> providerIds.add(s.getProviderId()));
        Map<UUID, Provider> providers = providerRepository.findAllById(providerIds).stream()
                .collect(Collectors.toMap(Provider::getId, Function.identity()));

        return bookings.stream().map(b -> {
            AvailabilitySlot slot = slots.get(b.getAvailabilitySlotId());
            ServiceOffering service = services.get(b.getServiceId());
            UUID providerId = slot != null ? slot.getProviderId()
                    : service != null ? service.getProviderId() : null;
            Provider provider = providerId == null ? null : providers.get(providerId);
            return BookingResponse.from(b, service == null ? null : service.getTitle(),
                    provider == null ? null
                            : new ProviderRef(provider.getId(), provider.getName(), provider.getVertical()),
                    slot == null ? null : new SlotTimes(slot.getStartsAt(), slot.getEndsAt()));
        }).toList();
    }

    public BookingResponse assemble(Booking booking) {
        return assemble(List.of(booking)).get(0);
    }
}
