package com.zairo.factory.vertical.beauty;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
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

    public BeautyBookingService(MasterRepository masterRepository,
            MasterServiceLinkRepository masterServiceLinkRepository, MasterBookingRepository masterBookingRepository,
            BookingService bookingService, BookingRepository bookingRepository) {
        this.masterRepository = masterRepository;
        this.masterServiceLinkRepository = masterServiceLinkRepository;
        this.masterBookingRepository = masterBookingRepository;
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
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

        Booking booking = bookingService.createBooking(userId, serviceId, availabilitySlotId, totalPrice);
        masterBookingRepository.save(new MasterBooking(UUID.randomUUID(), booking.getId(), masterId, Instant.now()));
        return new BeautyBookingResult(booking, masterId);
    }

    public BeautyBookingResult getBooking(UUID bookingId) {
        MasterBooking link = masterBookingRepository.findByBookingId(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not a beauty booking: "
                        + bookingId));
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        return new BeautyBookingResult(booking, link.getMasterId());
    }

    public record BeautyBookingResult(Booking booking, UUID masterId) {
    }
}
