package com.zairo.factory.booking;

import com.zairo.factory.booking.BookingDtos.BookingResponse;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class BookingController {

    private final BookingService bookingService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;

    public BookingController(BookingService bookingService, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository) {
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    @PostMapping("/api/v1/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public BookingResponse create(@RequestBody CreateBookingRequest request) {
        Booking booking = bookingService.createBooking(request.userId(), request.serviceId(),
                request.availabilitySlotId(), request.totalPrice());
        return BookingResponse.from(booking);
    }

    @GetMapping("/api/v1/bookings/{id}")
    public BookingResponse getById(@PathVariable UUID id) {
        return bookingRepository.findById(id).map(BookingResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: " + id));
    }

    @PostMapping("/api/v1/bookings/{id}/complete")
    public BookingResponse complete(@PathVariable UUID id) {
        return BookingResponse.from(bookingService.completeBooking(id));
    }

    @GetMapping("/api/v1/users/{userId}/bookings")
    public List<BookingResponse> listByUser(@PathVariable UUID userId) {
        return bookingRepository.findByUserId(userId).stream().map(BookingResponse::from).toList();
    }

    /**
     * For the Business Admin app: "which bookings has my salon received."
     * Booking has no providerId of its own (see docs/erd/core-domain.md —
     * it only references the slot/service by id), so this composes it via
     * the slot -> booking hop rather than adding a denormalized column.
     */
    @GetMapping("/api/v1/providers/{providerId}/bookings")
    public List<BookingResponse> listByProvider(@PathVariable UUID providerId) {
        List<UUID> slotIds = availabilitySlotRepository.findByProviderId(providerId).stream()
                .map(AvailabilitySlot::getId).toList();
        return bookingRepository.findByAvailabilitySlotIdIn(slotIds).stream().map(BookingResponse::from).toList();
    }
}
