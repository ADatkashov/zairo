package com.zairo.factory.vertical.beauty;

import com.zairo.factory.vertical.beauty.BeautyBookingDtos.BeautyBookingResponse;
import com.zairo.factory.vertical.beauty.BeautyBookingDtos.CreateBeautyBookingRequest;
import com.zairo.factory.vertical.beauty.BeautyBookingService.BeautyBookingResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Beauty — Bookings")
public class BeautyBookingController {

    private final BeautyBookingService beautyBookingService;

    public BeautyBookingController(BeautyBookingService beautyBookingService) {
        this.beautyBookingService = beautyBookingService;
    }

    @Operation(summary = "Create a beauty booking", description = """
            Like POST /bookings, but also names which Master performs it — and enforces that the master \
            actually offers the requested service (see POST /beauty/masters/{masterId}/services/{serviceId}). \
            No authentication is required by this endpoint itself — see Known Limitations in the project's \
            audit notes.

            **Workflow**: `Search -> Get master's services -> Create beauty booking` — link the service to \
            the master first if it isn't already.""")
    @ApiResponse(responseCode = "201", description = "Booking created, status PENDING, slot now BOOKED")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The master, service, or availability "
            + "slot doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The master doesn't offer this service, or the slot "
            + "isn't OPEN / was just claimed by a concurrent request.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/beauty/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public BeautyBookingResponse create(@Valid @RequestBody CreateBeautyBookingRequest request) {
        BeautyBookingResult result = beautyBookingService.createBooking(request.userId(), request.masterId(),
                request.serviceId(), request.availabilitySlotId(), request.totalPrice());
        return BeautyBookingResponse.from(result.booking(), result.masterId());
    }

    @Operation(summary = "Get a beauty booking by id")
    @ApiResponse(responseCode = "200", description = "The booking")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/beauty/bookings/{bookingId}")
    public BeautyBookingResponse getById(
            @Parameter(description = "The booking's id.") @PathVariable UUID bookingId) {
        BeautyBookingResult result = beautyBookingService.getBooking(bookingId);
        return BeautyBookingResponse.from(result.booking(), result.masterId());
    }
}
