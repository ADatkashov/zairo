package com.zairo.factory.booking;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.booking.BookingDtos.BookingResponse;
import com.zairo.factory.booking.BookingDtos.CancelBookingRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.booking.BookingDtos.ScheduleEntryResponse;
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
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
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
    private final BookingResponseAssembler responseAssembler;

    public BookingController(BookingService bookingService, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ProviderOwnership providerOwnership,
            BookingResponseAssembler responseAssembler) {
        this.responseAssembler = responseAssembler;
        this.bookingService = bookingService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
    }

    @Operation(summary = "Create a booking", description = """
            Reserves a Service at an Availability slot for a user — atomically claims the slot \
            (OPEN -> BOOKED), so two customers racing for the same slot resolve to one 201 and one 409. \
            Self-service only: the caller must be the exact user named by `userId` — can't book on behalf \
            of someone else. The created booking's `totalPrice`/`currency` always come from the service's \
            own current price — the request's `totalPrice` field is ignored, not trusted, so a client can't \
            set its own price.

            **Workflow**: `Search -> Get provider details -> Create booking` — this is the last step, using \
            a `serviceId`/`availabilitySlotId` pair found via GET /search/providers and \
            GET /providers/{id}/availability-slots.""")
    @ApiResponse(responseCode = "201", description = "Booking created, status PENDING, slot now BOOKED, priced "
            + "from the service's own current price")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "402", description = "The provider owner's subscription plan doesn't allow "
            + "another booking this month — upgrade for unlimited bookings.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", description = "userId doesn't match the caller's own id.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The service or the availability slot "
            + "doesn't exist.")
    @ApiResponse(responseCode = "409", description = "The slot isn't OPEN, was just claimed by a concurrent "
            + "request for someone else, or the service belongs to a different provider than the slot.",
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

    @Operation(summary = "Get a booking by id", description = "Restricted to the two parties involved: the "
            + "booking's own customer, or the owner of the provider the booking's slot belongs to.")
    @ApiResponse(responseCode = "200", description = "The booking")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is neither the booking's own customer nor "
            + "the owner of the provider it belongs to.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/bookings/{id}")
    public BookingResponse getById(@Parameter(description = "The booking's id.") @PathVariable UUID id,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        Booking booking = bookingRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: " + id));

        if (!booking.getUserId().equals(callerId)) {
            AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                            "Availability slot not found: " + booking.getAvailabilitySlotId()));
            providerOwnership.requireOwner(slot.getProviderId(), callerId);
        }

        return responseAssembler.assemble(booking);
    }

    @Operation(summary = "Mark a booking complete", description = "Only a CONFIRMED booking can be completed "
            + "— this is the gate Reviews checks before allowing a review (no review without a verified "
            + "visit). Provider-owner-only — the caller must own the provider the booking's slot belongs to, "
            + "same authorization as POST /bookings/{id}/no-show.")
    @ApiResponse(responseCode = "200", description = "Booking marked COMPLETED")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The booking isn't in a completable state (not "
            + "CONFIRMED).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/bookings/{id}/complete")
    public BookingResponse complete(@Parameter(description = "The booking's id.") @PathVariable UUID id,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        return BookingResponse.from(bookingService.completeBooking(id, callerId));
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
    @ApiResponse(responseCode = "200", description = "The user's bookings (empty list if none), each enriched "
            + "with serviceTitle, providerId/providerName/providerVertical and startsAt/endsAt")
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
        return responseAssembler.assemble(bookingRepository.findByUserId(userId));
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

    /** The widest window the schedule endpoint will answer for. */
    private static final Duration MAX_SCHEDULE_WINDOW = Duration.ofDays(31);

    @Operation(summary = "A provider's schedule for a time window", description = "For the Business Admin "
            + "agenda: the provider's bookings whose slot starts in [from, to), each with the slot's start "
            + "and end, oldest first. Cancelled bookings are included — filter on `status` as needed. "
            + "Owner-only: the caller must own the provider. The window may span at most 31 days.")
    @ApiResponse(responseCode = "200", description = "Schedule entries (empty list if none)")
    @ApiResponse(responseCode = "400", ref = "BadRequest", description = "`from` is not before `to`, or the "
            + "window is longer than 31 days.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/schedule")
    public List<ScheduleEntryResponse> schedule(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Window start, inclusive (ISO-8601 instant).") @RequestParam Instant from,
            @Parameter(description = "Window end, exclusive (ISO-8601 instant).") @RequestParam Instant to,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        if (!from.isBefore(to) || Duration.between(from, to).compareTo(MAX_SCHEDULE_WINDOW) > 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "`from` must be before `to`, at most 31 days apart");
        }
        Map<UUID, AvailabilitySlot> slots = availabilitySlotRepository
                .findByProviderIdAndStartsAtBetween(providerId, from, to).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        if (slots.isEmpty()) {
            return List.of();
        }
        return bookingRepository.findByAvailabilitySlotIdIn(List.copyOf(slots.keySet())).stream()
                .map(booking -> {
                    AvailabilitySlot slot = slots.get(booking.getAvailabilitySlotId());
                    return new ScheduleEntryResponse(booking.getId(), booking.getServiceId(), slot.getId(),
                            booking.getStatus(), slot.getStartsAt(), slot.getEndsAt(), booking.getTotalPrice(),
                            booking.getCurrency(), booking.getPaidAmount());
                })
                .sorted(Comparator.comparing(ScheduleEntryResponse::startsAt))
                .toList();
    }
}
