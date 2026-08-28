package com.zairo.factory.booking;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.booking.BookingDtos.BookingResponse;
import com.zairo.factory.booking.BookingDtos.CancelBookingRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.providers.ProviderOwnership;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
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
@Tag(name = "Bookings")
public class BookingController {

    private final BookingService bookingService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderOwnership providerOwnership;

    public BookingController(BookingService bookingService, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ProviderOwnership providerOwnership) {
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
    }

    @Operation(summary = "Create a booking", description = """
            Reserves a Service at an Availability slot for a user — atomically claims the slot \
            (OPEN -> BOOKED), so two customers racing for the same slot resolve to one 201 and one 409. \
            Self-service only: the caller must be the exact user named by `userId` — can't book on behalf \
            of someone else.

            **Workflow**: `Search -> Get provider details -> Create booking` — this is the last step, using \
            a `serviceId`/`availabilitySlotId` pair found via GET /search/providers and \
            GET /providers/{id}/availability-slots.""")
    @ApiResponse(responseCode = "201", description = "Booking created, status PENDING, slot now BOOKED")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "402", description = "The provider owner's subscription plan doesn't allow "
            + "another booking this month — upgrade for unlimited bookings.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", description = "userId doesn't match the caller's own id.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The availability slot doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The slot isn't OPEN, or was just claimed by a "
            + "concurrent request for someone else.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public BookingResponse create(@Valid @RequestBody CreateBookingRequest request, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(request.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot book on behalf of a different user");
        }
        Booking booking = bookingService.createBooking(request.userId(), request.serviceId(),
                request.availabilitySlotId(), request.totalPrice());
        return BookingResponse.from(booking);
    }

    @Operation(summary = "Get a booking by id")
    @ApiResponse(responseCode = "200", description = "The booking")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/bookings/{id}")
    public BookingResponse getById(@Parameter(description = "The booking's id.") @PathVariable UUID id) {
        return bookingRepository.findById(id).map(BookingResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: " + id));
    }

    @Operation(summary = "Mark a booking complete", description = "Only a CONFIRMED booking can be completed "
            + "— this is the gate Reviews checks before allowing a review (no review without a verified "
            + "visit). No authentication is required by this endpoint itself.")
    @ApiResponse(responseCode = "200", description = "Booking marked COMPLETED")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The booking isn't in a completable state (not "
            + "CONFIRMED).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/bookings/{id}/complete")
    public BookingResponse complete(@Parameter(description = "The booking's id.") @PathVariable UUID id) {
        return BookingResponse.from(bookingService.completeBooking(id));
    }

    @Operation(summary = "Cancel a booking", description = "Customer-only — the caller must be the booking's "
            + "own user. If it had been paid, the payment is automatically refunded as part of the same "
            + "cancellation (see the Payments module).")
    @ApiResponse(responseCode = "200", description = "Booking cancelled (and refunded, if it was paid)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The token belongs to a different user than the "
            + "booking's own.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The booking isn't in a cancellable state (already "
            + "CANCELLED or COMPLETED).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/bookings/{id}/cancel")
    public BookingResponse cancel(@Parameter(description = "The booking's id.") @PathVariable UUID id,
            @RequestBody(required = false) CancelBookingRequest request, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        String reason = request == null ? null : request.reason();
        return BookingResponse.from(bookingService.cancelBooking(id, callerId, reason));
    }

    @Operation(summary = "Mark a booking as a no-show", description = "Provider-owner-only — the caller must "
            + "own the provider the booking's slot belongs to. Only a CONFIRMED booking can be marked; this "
            + "and completing a booking are mutually exclusive outcomes for the same appointment.")
    @ApiResponse(responseCode = "200", description = "Booking marked NO_SHOW")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The booking isn't in a no-show-able state (not "
            + "CONFIRMED).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/bookings/{id}/no-show")
    public BookingResponse markNoShow(@Parameter(description = "The booking's id.") @PathVariable UUID id,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        return BookingResponse.from(bookingService.markNoShow(id, callerId));
    }

    @Operation(summary = "List a user's bookings", description = "Owner-only: the caller must be the exact "
            + "user named by `userId`.")
    @ApiResponse(responseCode = "200", description = "The user's bookings (empty list if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/bookings")
    public List<BookingResponse> listByUser(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot view another user's bookings");
        }
        return bookingRepository.findByUserId(userId).stream().map(BookingResponse::from).toList();
    }

    @Operation(summary = "List a provider's received bookings", description = "For the Business Admin app: "
            + "\"which bookings has my salon received.\" Booking has no providerId of its own — this "
            + "composes it via the availability-slot -> booking hop. Owner-only: the caller must own the "
            + "provider.")
    @ApiResponse(responseCode = "200", description = "Bookings against this provider's slots (empty list if "
            + "none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/bookings")
    public List<BookingResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        List<UUID> slotIds = availabilitySlotRepository.findByProviderId(providerId).stream()
                .map(AvailabilitySlot::getId).toList();
        return bookingRepository.findByAvailabilitySlotIdIn(slotIds).stream().map(BookingResponse::from).toList();
    }
}
