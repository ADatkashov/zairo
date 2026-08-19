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

    public BookingController(BookingService bookingService, BookingRepository bookingRepository) {
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
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
}
