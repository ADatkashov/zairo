package com.zairo.factory.booking;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class BookingService {

    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final BookingRepository bookingRepository;
    private final ApplicationEventPublisher eventPublisher;

    public BookingService(AvailabilitySlotRepository availabilitySlotRepository, BookingRepository bookingRepository,
            ApplicationEventPublisher eventPublisher) {
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.bookingRepository = bookingRepository;
        this.eventPublisher = eventPublisher;
    }

    /**
     * Atomically claims the slot (OPEN -> BOOKED) and creates a confirmed
     * booking in one transaction. {@code @Version} on AvailabilitySlot means
     * a concurrent request for the same slot fails with
     * OptimisticLockingFailureException, which we turn into 409 — the slot
     * can't be double-booked even under concurrent requests.
     */
    @Transactional
    public Booking createBooking(UUID userId, UUID serviceId, UUID availabilitySlotId, BigDecimal totalPrice) {
        AvailabilitySlot slot = availabilitySlotRepository.findById(availabilitySlotId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Availability slot not found: " + availabilitySlotId));

        if (slot.getStatus() != AvailabilityStatus.OPEN) {
            throw new SlotNotAvailableException("Availability slot is not open: " + availabilitySlotId);
        }

        try {
            slot.markBooked();
            availabilitySlotRepository.saveAndFlush(slot);
        } catch (OptimisticLockingFailureException e) {
            throw new SlotNotAvailableException("Availability slot was just booked by someone else: "
                    + availabilitySlotId);
        }

        Booking booking = new Booking(UUID.randomUUID(), userId, serviceId, availabilitySlotId,
                BookingStatus.CONFIRMED, totalPrice, Instant.now());
        booking = bookingRepository.save(booking);

        eventPublisher.publishEvent(new BookingConfirmedEvent(booking.getId(), userId, slot.getProviderId()));
        return booking;
    }
}
