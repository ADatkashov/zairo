package com.zairo.factory.vertical.auto;

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
 * Enforces the two auto booking rules ("the named mechanic must offer the
 * requested service" and "the vehicle must belong to the booking's own
 * user") and then delegates the actual slot-claim/booking creation to
 * Core's {@link BookingService} — see build.gradle.kts for why this calls
 * into another module's service, not just its repository.
 */
@Service
public class AutoBookingService {

    private final MechanicRepository mechanicRepository;
    private final MechanicServiceLinkRepository mechanicServiceLinkRepository;
    private final VehicleRepository vehicleRepository;
    private final AutoBookingRepository autoBookingRepository;
    private final BookingService bookingService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderOwnership providerOwnership;
    private final ObjectProvider<WorkerAvailabilityGuard> availabilityGuards;

    public AutoBookingService(MechanicRepository mechanicRepository,
            MechanicServiceLinkRepository mechanicServiceLinkRepository, VehicleRepository vehicleRepository,
            AutoBookingRepository autoBookingRepository, BookingService bookingService,
            BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            ProviderOwnership providerOwnership,
            ObjectProvider<WorkerAvailabilityGuard> availabilityGuards) {
        this.mechanicRepository = mechanicRepository;
        this.mechanicServiceLinkRepository = mechanicServiceLinkRepository;
        this.vehicleRepository = vehicleRepository;
        this.autoBookingRepository = autoBookingRepository;
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
        this.availabilityGuards = availabilityGuards;
    }

    @Transactional
    public AutoBookingResult createBooking(UUID userId, UUID mechanicId, UUID vehicleId, UUID serviceId,
            UUID availabilitySlotId, BigDecimal totalPrice) {
        if (!mechanicRepository.existsById(mechanicId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Mechanic not found: " + mechanicId);
        }
        Vehicle vehicle = vehicleRepository.findById(vehicleId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Vehicle not found: "
                        + vehicleId));
        if (!vehicle.getOwnerUserId().equals(userId)) {
            throw new VehicleNotOwnedByUserException("Vehicle " + vehicleId + " does not belong to user " + userId);
        }
        if (!mechanicServiceLinkRepository.existsByMechanicIdAndServiceId(mechanicId, serviceId)) {
            throw new MechanicDoesNotOfferServiceException("Mechanic " + mechanicId + " does not offer service "
                    + serviceId);
        }
        // A slot generated for one specific mechanic can't be claimed under
        // a different mechanic's name — same rule as vertical-beauty's own
        // master check, see AvailabilitySlot's doc comment.
        AvailabilitySlot slot = availabilitySlotRepository.findById(availabilitySlotId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + availabilitySlotId));
        if (slot.getEmployeeId() != null && !slot.getEmployeeId().equals(mechanicId)) {
            throw new SlotNotAvailableException(
                    "Availability slot " + availabilitySlotId + " belongs to a different mechanic");
        }

        // Workforce rules (not double-booked elsewhere, not off, choice allowed): see WorkerAvailabilityGuard.
        availabilityGuards.orderedStream().forEach(guard -> guard.requireBookable(mechanicId, slot, userId));

        Booking booking = bookingService.createBooking(userId, serviceId, availabilitySlotId, totalPrice);
        autoBookingRepository.save(new AutoBooking(UUID.randomUUID(), booking.getId(), mechanicId, vehicleId,
                Instant.now()));
        return new AutoBookingResult(booking, mechanicId, vehicleId);
    }

    /**
     * Restricted to the two parties involved: the booking's own customer, or
     * the owner of the provider the booking's slot belongs to — same check
     * as core {@code BookingController.getById} (see PR #57), reused here
     * rather than reinvented.
     */
    public AutoBookingResult getBooking(UUID bookingId, UUID callerId) {
        AutoBooking link = autoBookingRepository.findByBookingId(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not an auto booking: "
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

        return new AutoBookingResult(booking, link.getMechanicId(), link.getVehicleId());
    }

    public record AutoBookingResult(Booking booking, UUID mechanicId, UUID vehicleId) {
    }
}
