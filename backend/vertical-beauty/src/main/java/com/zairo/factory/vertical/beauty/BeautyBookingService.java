package com.zairo.factory.vertical.beauty;

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
 * Enforces the beauty booking rule ("the named master must offer the
 * requested service") and then delegates the actual slot-claim/booking
 * creation to Core's {@link BookingService} — see build.gradle.kts for why
 * this calls into another module's service, not just its repository.
 */
@Service
public class BeautyBookingService {

    private final MasterRepository masterRepository;
    private final MasterServiceLinkRepository masterServiceLinkRepository;
    private final MasterBookingRepository masterBookingRepository;
    private final BookingService bookingService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderOwnership providerOwnership;
    private final ObjectProvider<WorkerAvailabilityGuard> availabilityGuards;

    public BeautyBookingService(MasterRepository masterRepository,
            MasterServiceLinkRepository masterServiceLinkRepository, MasterBookingRepository masterBookingRepository,
            BookingService bookingService, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ProviderOwnership providerOwnership,
            ObjectProvider<WorkerAvailabilityGuard> availabilityGuards) {
        this.masterRepository = masterRepository;
        this.masterServiceLinkRepository = masterServiceLinkRepository;
        this.masterBookingRepository = masterBookingRepository;
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
        this.availabilityGuards = availabilityGuards;
    }

    @Transactional
    public BeautyBookingResult createBooking(UUID userId, UUID masterId, UUID serviceId, UUID availabilitySlotId,
            BigDecimal totalPrice) {
        if (!masterRepository.existsById(masterId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Master not found: " + masterId);
        }
        if (!masterServiceLinkRepository.existsByMasterIdAndServiceId(masterId, serviceId)) {
            throw new MasterDoesNotOfferServiceException("Master " + masterId + " does not offer service "
                    + serviceId);
        }
        // A slot generated for one specific master can't be claimed under a
        // different master's name — null employeeId (the shared-pool case,
        // still the default) imposes no such restriction. See
        // AvailabilitySlot's own doc comment.
        AvailabilitySlot slot = availabilitySlotRepository.findById(availabilitySlotId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + availabilitySlotId));
        if (slot.getEmployeeId() != null && !slot.getEmployeeId().equals(masterId)) {
            throw new SlotNotAvailableException(
                    "Availability slot " + availabilitySlotId + " belongs to a different master");
        }

        // Workforce rules (not double-booked elsewhere, not off, choice allowed): see WorkerAvailabilityGuard.
        availabilityGuards.orderedStream().forEach(guard -> guard.requireBookable(masterId, slot, userId));

        Booking booking = bookingService.createBooking(userId, serviceId, availabilitySlotId, totalPrice);
        masterBookingRepository.save(new MasterBooking(UUID.randomUUID(), booking.getId(), masterId, Instant.now()));
        return new BeautyBookingResult(booking, masterId);
    }

    /**
     * Restricted to the two parties involved: the booking's own customer, or
     * the owner of the provider the booking's slot belongs to — same check
     * as core {@code BookingController.getById} (see PR #57), reused here
     * rather than reinvented.
     */
    public BeautyBookingResult getBooking(UUID bookingId, UUID callerId) {
        MasterBooking link = masterBookingRepository.findByBookingId(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not a beauty booking: "
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

        return new BeautyBookingResult(booking, link.getMasterId());
    }

    public record BeautyBookingResult(Booking booking, UUID masterId) {
    }
}
