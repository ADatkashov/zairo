package com.zairo.factory.vertical.auto;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.vertical.auto.AutoBookingDtos.AutoBookingResponse;
import com.zairo.factory.vertical.auto.AutoBookingDtos.CreateAutoBookingRequest;
import com.zairo.factory.vertical.auto.AutoBookingService.AutoBookingResult;
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
@Tag(name = "Auto — Bookings")
public class AutoBookingController {

    private final AutoBookingService autoBookingService;

    public AutoBookingController(AutoBookingService autoBookingService) {
        this.autoBookingService = autoBookingService;
    }

    @Operation(summary = "Create an auto booking", description = """
            Like POST /bookings, but also names which Mechanic performs it and which Vehicle it's for — \
            and enforces that the mechanic actually offers the requested service (see POST \
            /auto/mechanics/{mechanicId}/services/{serviceId}) and that the vehicle belongs to `userId` \
            (see POST /vehicles). Self-service only: the caller must be the exact user named by `userId` \
            — can't book on behalf of someone else.

            **Workflow**: `Search -> Get mechanic's services -> Register a vehicle -> Create auto booking` \
            — link the service to the mechanic first if it isn't already, and register the vehicle first \
            if it isn't already.""")
    @ApiResponse(responseCode = "201", description = "Booking created, status PENDING, slot now BOOKED")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "userId doesn't match the caller's own id, or the "
            + "vehicle doesn't belong to userId.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The mechanic, vehicle, service, or "
            + "availability slot doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The mechanic doesn't offer this service, or the slot "
            + "isn't OPEN / was just claimed by a concurrent request.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auto/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public AutoBookingResponse create(@Valid @RequestBody CreateAutoBookingRequest request) {
        UUID callerId = CurrentUser.requireUserId();
        if (!callerId.equals(request.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot book on behalf of a different user");
        }
        AutoBookingResult result = autoBookingService.createBooking(request.userId(), request.mechanicId(),
                request.vehicleId(), request.serviceId(), request.availabilitySlotId(), request.totalPrice());
        return AutoBookingResponse.from(result.booking(), result.mechanicId(), result.vehicleId());
    }

    @Operation(summary = "Get an auto booking by id", description = "Restricted to the two parties involved: "
            + "the booking's own customer, or the owner of the provider the booking's slot belongs to.")
    @ApiResponse(responseCode = "200", description = "The booking")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is neither the booking's own customer nor "
            + "the owner of the provider it belongs to.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/auto/bookings/{bookingId}")
    public AutoBookingResponse getById(
            @Parameter(description = "The booking's id.") @PathVariable UUID bookingId) {
        UUID callerId = CurrentUser.requireUserId();
        AutoBookingResult result = autoBookingService.getBooking(bookingId, callerId);
        return AutoBookingResponse.from(result.booking(), result.mechanicId(), result.vehicleId());
    }
}
