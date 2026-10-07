package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/** Looks up a worker's still-active appointments. Shared by time off, "can't attend" and (later) reassignment. */
@Component
public class WorkerBookings {

    /** An active booking together with the slot it sits on. */
    public record ActiveBooking(Booking booking, AvailabilitySlot slot) {
    }

    private final WorkerCatalog catalog;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository slotRepository;

    public WorkerBookings(WorkerCatalog catalog, BookingRepository bookingRepository,
            AvailabilitySlotRepository slotRepository) {
        this.catalog = catalog;
        this.bookingRepository = bookingRepository;
        this.slotRepository = slotRepository;
    }

    /** CONFIRMED / PENDING_PAYMENT bookings of the worker whose slot overlaps [from, to). */
    public List<ActiveBooking> activeOverlapping(Worker worker, Instant from, Instant to) {
        List<UUID> ids = List.copyOf(catalog.bookingIdsOf(worker));
        if (ids.isEmpty()) {
            return List.of();
        }
        List<Booking> bookings = bookingRepository.findAllById(ids).stream()
                .filter(b -> b.getStatus() == BookingStatus.CONFIRMED || b.getStatus() == BookingStatus.PENDING_PAYMENT)
                .toList();
        Map<UUID, AvailabilitySlot> slots = slotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        List<ActiveBooking> result = new ArrayList<>();
        for (Booking booking : bookings) {
            AvailabilitySlot slot = slots.get(booking.getAvailabilitySlotId());
            if (slot != null && slot.getStartsAt().isBefore(to) && slot.getEndsAt().isAfter(from)) {
                result.add(new ActiveBooking(booking, slot));
            }
        }
        return result;
    }
}
