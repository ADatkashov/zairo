package com.zairo.factory.staff;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.booking.SlotNotAvailableException;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Enforces the staff booking rule ("the named staff member must offer the
 * requested service") and then delegates the actual slot-claim/booking
 * creation to Core's {@link BookingService} — mirrors
 * {@code CleaningBookingService} exactly, just for any-category staff.
 */
@Service
public class StaffBookingService {

    private final StaffRepository staffRepository;
    private final StaffServiceLinkRepository staffServiceLinkRepository;
    private final StaffBookingRepository staffBookingRepository;
    private final BookingService bookingService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;

    public StaffBookingService(StaffRepository staffRepository,
            StaffServiceLinkRepository staffServiceLinkRepository, StaffBookingRepository staffBookingRepository,
            BookingService bookingService, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository) {
        this.staffRepository = staffRepository;
        this.staffServiceLinkRepository = staffServiceLinkRepository;
        this.staffBookingRepository = staffBookingRepository;
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    @Transactional
    public StaffBookingResult createBooking(UUID userId, UUID staffId, UUID serviceId, UUID availabilitySlotId,
            BigDecimal totalPrice) {
        if (!staffRepository.existsById(staffId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Staff not found: " + staffId);
        }
        if (!staffServiceLinkRepository.existsByStaffIdAndServiceId(staffId, serviceId)) {
            throw new StaffDoesNotOfferServiceException("Staff " + staffId + " does not offer service " + serviceId);
        }
        // A slot generated for one specific staff member can't be claimed
        // under a different staff member's name — null employeeId (the
        // shared-pool case, still the default) imposes no such restriction.
        // See AvailabilitySlot's own doc comment.
        AvailabilitySlot slot = availabilitySlotRepository.findById(availabilitySlotId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + availabilitySlotId));
        if (slot.getEmployeeId() != null && !slot.getEmployeeId().equals(staffId)) {
            throw new SlotNotAvailableException(
                    "Availability slot " + availabilitySlotId + " belongs to a different staff member");
        }

        Booking booking = bookingService.createBooking(userId, serviceId, availabilitySlotId, totalPrice);
        staffBookingRepository.save(new StaffBooking(UUID.randomUUID(), booking.getId(), staffId, Instant.now()));
        return new StaffBookingResult(booking, staffId);
    }

    public StaffBookingResult getBooking(UUID bookingId) {
        StaffBooking link = staffBookingRepository.findByBookingId(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not a staff booking: "
                        + bookingId));
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        return new StaffBookingResult(booking, link.getStaffId());
    }

    public record StaffBookingResult(Booking booking, UUID staffId) {
    }
}
