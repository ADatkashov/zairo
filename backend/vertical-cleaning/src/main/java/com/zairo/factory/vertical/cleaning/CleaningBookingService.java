package com.zairo.factory.vertical.cleaning;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.booking.SlotNotAvailableException;
import com.zairo.factory.booking.WorkerAvailabilityGuard;
import com.zairo.factory.providers.ProviderOwnership;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Enforces the cleaning booking rule ("the named cleaner must offer the
 * requested service") and then delegates the actual slot-claim/booking
 * creation to Core's {@link BookingService} — see build.gradle.kts for why
 * this calls into another module's service, not just its repository.
 */
@Service
public class CleaningBookingService {

    private final CleanerRepository cleanerRepository;
    private final CleanerServiceLinkRepository cleanerServiceLinkRepository;
    private final CleaningBookingRepository cleaningBookingRepository;
    private final BookingService bookingService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderOwnership providerOwnership;
    private final ObjectProvider<WorkerAvailabilityGuard> availabilityGuards;

    public CleaningBookingService(CleanerRepository cleanerRepository,
            CleanerServiceLinkRepository cleanerServiceLinkRepository,
            CleaningBookingRepository cleaningBookingRepository, BookingService bookingService,
            BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            ProviderOwnership providerOwnership,
            ObjectProvider<WorkerAvailabilityGuard> availabilityGuards) {
        this.cleanerRepository = cleanerRepository;
        this.cleanerServiceLinkRepository = cleanerServiceLinkRepository;
        this.cleaningBookingRepository = cleaningBookingRepository;
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
        this.availabilityGuards = availabilityGuards;
    }

    @Transactional
    public CleaningBookingResult createBooking(UUID userId, UUID cleanerId, UUID serviceId, UUID availabilitySlotId,
            BigDecimal totalPrice) {
        if (!cleanerRepository.existsById(cleanerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Cleaner not found: " + cleanerId);
        }
        if (!cleanerServiceLinkRepository.existsByCleanerIdAndServiceId(cleanerId, serviceId)) {
            throw new CleanerDoesNotOfferServiceException("Cleaner " + cleanerId + " does not offer service "
                    + serviceId);
        }
        // A slot generated for one specific cleaner can't be claimed under a
        // different cleaner's name — null employeeId (the shared-pool case,
        // still the default) imposes no such restriction. See
        // AvailabilitySlot's own doc comment.
        AvailabilitySlot slot = availabilitySlotRepository.findById(availabilitySlotId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + availabilitySlotId));
        if (slot.getEmployeeId() != null && !slot.getEmployeeId().equals(cleanerId)) {
            throw new SlotNotAvailableException(
                    "Availability slot " + availabilitySlotId + " belongs to a different cleaner");
        }

        // Workforce rules (not double-booked elsewhere, not off, choice allowed): see WorkerAvailabilityGuard.
        availabilityGuards.orderedStream().forEach(guard -> guard.requireBookable(cleanerId, slot, userId));

        Booking booking = bookingService.createBooking(userId, serviceId, availabilitySlotId, totalPrice);
        cleaningBookingRepository.save(
                new CleaningBooking(UUID.randomUUID(), booking.getId(), cleanerId, Instant.now()));
        return new CleaningBookingResult(booking, cleanerId);
    }

    /**
     * Restricted to the two parties involved: the booking's own customer, or
     * the owner of the provider the booking's slot belongs to — same check
     * as core {@code BookingController.getById} (see PR #57), reused here
     * rather than reinvented.
     */
    public CleaningBookingResult getBooking(UUID bookingId, UUID callerId) {
        CleaningBooking link = cleaningBookingRepository.findByBookingId(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not a cleaning booking: "
                        + bookingId));
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        if (!booking.getUserId().equals(callerId)) {
            AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                            "Availability slot not found: " + booking.getAvailabilitySlotId()));
            providerOwnership.requireOwner(slot.getProviderId(), callerId);
        }

        return new CleaningBookingResult(booking, link.getCleanerId());
    }

    public record CleaningBookingResult(Booking booking, UUID cleanerId) {
    }
}
