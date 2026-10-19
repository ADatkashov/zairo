package com.zairo.factory.vertical.cleaning;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.vertical.cleaning.CleaningBookingDtos.CleaningBookingResponse;
import com.zairo.factory.vertical.cleaning.CleaningBookingDtos.CreateCleaningBookingRequest;
import com.zairo.factory.vertical.cleaning.CleaningBookingService.CleaningBookingResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
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
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Cleaning — Bookings")
public class CleaningBookingController {

    private final CleaningBookingService cleaningBookingService;

    public CleaningBookingController(CleaningBookingService cleaningBookingService) {
        this.cleaningBookingService = cleaningBookingService;
    }

    @Operation(summary = "Create a cleaning booking", description = """
            Like POST /bookings, but also names which Cleaner performs it — and enforces that the cleaner \
            actually offers the requested service (see POST /cleaning/cleaners/{cleanerId}/services/{serviceId}). \
            Self-service only: the caller must be the exact user named by `userId` — can't book on behalf \
            of someone else.

            **Workflow**: `Search -> Get cleaner's services -> Create cleaning booking` — link the service to \
            the cleaner first if it isn't already.""")
    @ApiResponse(responseCode = "201", description = "Booking created, status PENDING, slot now BOOKED")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "userId doesn't match the caller's own id.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The cleaner, service, or availability "
            + "slot doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The cleaner doesn't offer this service, or the slot "
            + "isn't OPEN / was just claimed by a concurrent request.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/cleaning/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public CleaningBookingResponse create(@Valid @RequestBody CreateCleaningBookingRequest request) {
        UUID callerId = CurrentUser.requireUserId();
        if (!callerId.equals(request.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot book on behalf of a different user");
        }
        CleaningBookingResult result = cleaningBookingService.createBooking(request.userId(), request.cleanerId(),
                request.serviceId(), request.availabilitySlotId(), request.totalPrice());
        return CleaningBookingResponse.from(result.booking(), result.cleanerId());
    }

    @Operation(summary = "Get a cleaning booking by id", description = "Restricted to the two parties involved: "
            + "the booking's own customer, or the owner of the provider the booking's slot belongs to.")
    @ApiResponse(responseCode = "200", description = "The booking")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is neither the booking's own customer nor "
            + "the owner of the provider it belongs to.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/cleaning/bookings/{bookingId}")
    public CleaningBookingResponse getById(
            @Parameter(description = "The booking's id.") @PathVariable UUID bookingId) {
        UUID callerId = CurrentUser.requireUserId();
        CleaningBookingResult result = cleaningBookingService.getBooking(bookingId, callerId);
        return CleaningBookingResponse.from(result.booking(), result.cleanerId());
    }
}
