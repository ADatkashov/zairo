package com.zairo.factory.booking;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.booking.AvailabilitySlotDtos.AvailabilitySlotResponse;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleResult;
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
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Availability")
public class AvailabilitySlotController {

    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderOwnership providerOwnership;
    private final RecurringScheduleService recurringScheduleService;

    public AvailabilitySlotController(AvailabilitySlotRepository availabilitySlotRepository,
            ProviderOwnership providerOwnership, RecurringScheduleService recurringScheduleService) {
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
        this.recurringScheduleService = recurringScheduleService;
    }

    @Operation(summary = "Add a single availability slot", description = "Owner-only. Always created OPEN.")
    @ApiResponse(responseCode = "201", description = "Slot created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/availability-slots")
    @ResponseStatus(HttpStatus.CREATED)
    public AvailabilitySlotResponse create(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateAvailabilitySlotRequest request, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        AvailabilitySlot slot = new AvailabilitySlot(UUID.randomUUID(), providerId, request.startsAt(),
                request.endsAt(), AvailabilityStatus.OPEN);
        return AvailabilitySlotResponse.from(availabilitySlotRepository.save(slot));
    }

    @Operation(summary = "Generate a recurring weekly schedule", description = """
            Owner-only. Generates real OPEN slots from a weekly day-of-week/time-range pattern over a date \
            range (max 92 days) — see the request schema for every field's own constraints. Safe to call \
            repeatedly: a candidate slot that would overlap an already-existing slot (any status) is \
            skipped, not overwritten or duplicated — `skippedConflictCount` reports how many.""")
    @ApiResponse(responseCode = "201", description = "Slots generated (possibly zero, if every candidate "
            + "conflicted)")
    @ApiResponse(responseCode = "400", description = "A field violates one of the constraints described on the "
            + "request schema (e.g. startTime not before endTime, non-positive slotDurationMinutes, range "
            + "over 92 days, missing/invalid zoneId).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/availability-slots/recurring")
    @ResponseStatus(HttpStatus.CREATED)
    public RecurringScheduleResult createRecurring(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @RequestBody RecurringScheduleRequest request, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return recurringScheduleService.generate(providerId, request);
    }

    @Operation(summary = "List a provider's availability slots", description = "Every slot regardless of "
            + "status (OPEN/HELD/BOOKED). No authentication required.")
    @ApiResponse(responseCode = "200", description = "The provider's slots")
    @GetMapping("/api/v1/providers/{providerId}/availability-slots")
    public List<AvailabilitySlotResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return availabilitySlotRepository.findByProviderId(providerId).stream()
                .map(AvailabilitySlotResponse::from).toList();
    }

    @Operation(summary = "Remove an availability slot", description = "Owner-only. Only an OPEN slot can be "
            + "removed — a BOOKED one has a real booking against it, and cancelling that is a separate "
            + "concern (see POST /bookings/{id}/cancel).")
    @ApiResponse(responseCode = "204", description = "Slot removed")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The slot isn't OPEN (it's HELD or BOOKED).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/availability-slots/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@Parameter(description = "The slot's id.") @PathVariable UUID id,
            HttpServletRequest httpRequest) {
        AvailabilitySlot slot = availabilitySlotRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + id));
        providerOwnership.requireOwner(slot.getProviderId(), CurrentUser.requireUserId(httpRequest));
        if (slot.getStatus() != AvailabilityStatus.OPEN) {
            throw new SlotNotAvailableException("Only an open slot can be removed: " + id);
        }
        availabilitySlotRepository.delete(slot);
    }
}
