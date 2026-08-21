package com.zairo.factory.booking;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.booking.AvailabilitySlotDtos.AvailabilitySlotResponse;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleResult;
import com.zairo.factory.providers.ProviderOwnership;
import jakarta.servlet.http.HttpServletRequest;
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

    /** Owner-only. */
    @PostMapping("/api/v1/providers/{providerId}/availability-slots")
    @ResponseStatus(HttpStatus.CREATED)
    public AvailabilitySlotResponse create(@PathVariable UUID providerId,
            @RequestBody CreateAvailabilitySlotRequest request, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        AvailabilitySlot slot = new AvailabilitySlot(UUID.randomUUID(), providerId, request.startsAt(),
                request.endsAt(), AvailabilityStatus.OPEN);
        return AvailabilitySlotResponse.from(availabilitySlotRepository.save(slot));
    }

    /** Owner-only. Generates real slots from a weekly pattern — see RecurringScheduleService. */
    @PostMapping("/api/v1/providers/{providerId}/availability-slots/recurring")
    @ResponseStatus(HttpStatus.CREATED)
    public RecurringScheduleResult createRecurring(@PathVariable UUID providerId,
            @RequestBody RecurringScheduleRequest request, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return recurringScheduleService.generate(providerId, request);
    }

    @GetMapping("/api/v1/providers/{providerId}/availability-slots")
    public List<AvailabilitySlotResponse> listByProvider(@PathVariable UUID providerId) {
        return availabilitySlotRepository.findByProviderId(providerId).stream()
                .map(AvailabilitySlotResponse::from).toList();
    }

    /** Only an OPEN slot can be removed — a BOOKED one has a real booking against it, and cancelling that is a separate future concern. */
    @DeleteMapping("/api/v1/availability-slots/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id, HttpServletRequest httpRequest) {
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
