package com.zairo.factory.customerintelligence;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/**
 * Joins {@code Booking} with its {@code AvailabilitySlot} in a fixed, small
 * number of bulk queries -- same "one query per data source, no N+1"
 * discipline {@code smartfill.CandidateFinder} and {@code
 * providerinsights.ProviderInsightsService} already follow for the same
 * underlying tables.
 */
@Component
class BookingHistoryReader {

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;

    BookingHistoryReader(BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    /** Every booking (any status, any business) this customer has ever made -- the source for {@link CustomerProfile}. */
    List<VisitRecord> forUser(UUID userId) {
        return join(bookingRepository.findByUserId(userId));
    }

    /** Every booking (any status) this customer has made with one specific business -- the source for {@link CustomerProviderProfile}. */
    List<VisitRecord> forUserAndProvider(UUID userId, UUID providerId) {
        return join(bookingRepository.findByUserIdAndProviderId(userId, providerId));
    }

    private List<VisitRecord> join(List<Booking> bookings) {
        if (bookings.isEmpty()) {
            return List.of();
        }
        Map<UUID, AvailabilitySlot> slotsById = availabilitySlotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, slot -> slot));

        List<VisitRecord> visits = new ArrayList<>(bookings.size());
        for (Booking booking : bookings) {
            AvailabilitySlot slot = slotsById.get(booking.getAvailabilitySlotId());
            if (slot == null) {
                // Should not happen (a booking always references a real slot at creation time), but a
                // deleted/inconsistent row must not blow up a whole recalculation -- skip it, same
                // defensive style CandidateFinder's own Objects::nonNull filters use.
                continue;
            }
            visits.add(new VisitRecord(booking.getId(), slot.getProviderId(), booking.getServiceId(),
                    slot.getEmployeeId(), booking.getStatus(), slot.getStartsAt(), booking.getCreatedAt(),
                    booking.getTotalPrice(), booking.getCurrency()));
        }
        return visits;
    }
}
