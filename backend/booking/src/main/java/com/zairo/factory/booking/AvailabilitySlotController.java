package com.zairo.factory.booking;

import com.zairo.factory.booking.AvailabilitySlotDtos.AvailabilitySlotResponse;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
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

    public AvailabilitySlotController(AvailabilitySlotRepository availabilitySlotRepository) {
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    @PostMapping("/api/v1/providers/{providerId}/availability-slots")
    @ResponseStatus(HttpStatus.CREATED)
    public AvailabilitySlotResponse create(@PathVariable UUID providerId,
            @RequestBody CreateAvailabilitySlotRequest request) {
        AvailabilitySlot slot = new AvailabilitySlot(UUID.randomUUID(), providerId, request.startsAt(),
                request.endsAt(), AvailabilityStatus.OPEN);
        return AvailabilitySlotResponse.from(availabilitySlotRepository.save(slot));
    }

    @GetMapping("/api/v1/providers/{providerId}/availability-slots")
    public List<AvailabilitySlotResponse> listByProvider(@PathVariable UUID providerId) {
        return availabilitySlotRepository.findByProviderId(providerId).stream()
                .map(AvailabilitySlotResponse::from).toList();
    }

    /** Only an OPEN slot can be removed — a BOOKED one has a real booking against it, and cancelling that is a separate future concern. */
    @DeleteMapping("/api/v1/availability-slots/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        AvailabilitySlot slot = availabilitySlotRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + id));
        if (slot.getStatus() != AvailabilityStatus.OPEN) {
            throw new SlotNotAvailableException("Only an open slot can be removed: " + id);
        }
        availabilitySlotRepository.delete(slot);
    }
}
