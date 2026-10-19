package com.zairo.factory.staff;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.staff.StaffBookingDtos.CreateStaffBookingRequest;
import com.zairo.factory.staff.StaffBookingDtos.StaffBookingResponse;
import com.zairo.factory.staff.StaffBookingService.StaffBookingResult;
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
@Tag(name = "Staff — Bookings")
public class StaffBookingController {

    private final StaffBookingService staffBookingService;

    public StaffBookingController(StaffBookingService staffBookingService) {
        this.staffBookingService = staffBookingService;
    }

    @Operation(summary = "Create a staff booking", description = """
            Like POST /bookings, but also names which staff member performs it — and enforces that the staff \
            member actually offers the requested service (see POST /staff/{staffId}/services/{serviceId}). \
            Works for a provider in any category. Self-service only: the caller must be the exact user named \
            by `userId` — can't book on behalf of someone else.

            **Workflow**: `Search -> Get staff member's services -> Create staff booking` — link the service to \
            the staff member first if it isn't already.""")
    @ApiResponse(responseCode = "201", description = "Booking created, status PENDING, slot now BOOKED")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "userId doesn't match the caller's own id.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The staff member, service, or availability "
            + "slot doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The staff member doesn't offer this service, or the slot "
            + "isn't OPEN / was just claimed by a concurrent request.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/staff/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public StaffBookingResponse create(@Valid @RequestBody CreateStaffBookingRequest request) {
        UUID callerId = CurrentUser.requireUserId();
        if (!callerId.equals(request.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot book on behalf of a different user");
        }
        StaffBookingResult result = staffBookingService.createBooking(request.userId(), request.staffId(),
                request.serviceId(), request.availabilitySlotId(), request.totalPrice());
        return StaffBookingResponse.from(result.booking(), result.staffId());
    }

    @Operation(summary = "Get a staff booking by id", description = "Restricted to the two parties involved: "
            + "the booking's own customer, or the owner of the provider the booking's slot belongs to.")
    @ApiResponse(responseCode = "200", description = "The booking")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is neither the booking's own customer nor "
            + "the owner of the provider it belongs to.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/staff/bookings/{bookingId}")
    public StaffBookingResponse getById(@Parameter(description = "The booking's id.") @PathVariable UUID bookingId) {
        UUID callerId = CurrentUser.requireUserId();
        StaffBookingResult result = staffBookingService.getBooking(bookingId, callerId);
        return StaffBookingResponse.from(result.booking(), result.staffId());
    }
}
