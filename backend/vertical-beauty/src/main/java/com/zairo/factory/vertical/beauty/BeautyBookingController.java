package com.zairo.factory.vertical.beauty;

import com.zairo.factory.vertical.beauty.BeautyBookingDtos.BeautyBookingResponse;
import com.zairo.factory.vertical.beauty.BeautyBookingDtos.CreateBeautyBookingRequest;
import com.zairo.factory.vertical.beauty.BeautyBookingService.BeautyBookingResult;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class BeautyBookingController {

    private final BeautyBookingService beautyBookingService;

    public BeautyBookingController(BeautyBookingService beautyBookingService) {
        this.beautyBookingService = beautyBookingService;
    }

    @PostMapping("/api/v1/beauty/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public BeautyBookingResponse create(@RequestBody CreateBeautyBookingRequest request) {
        BeautyBookingResult result = beautyBookingService.createBooking(request.userId(), request.masterId(),
                request.serviceId(), request.availabilitySlotId(), request.totalPrice());
        return BeautyBookingResponse.from(result.booking(), result.masterId());
    }

    @GetMapping("/api/v1/beauty/bookings/{bookingId}")
    public BeautyBookingResponse getById(@PathVariable UUID bookingId) {
        BeautyBookingResult result = beautyBookingService.getBooking(bookingId);
        return BeautyBookingResponse.from(result.booking(), result.masterId());
    }
}
