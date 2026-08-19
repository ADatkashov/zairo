package com.zairo.factory.booking;

import java.time.Instant;
import java.util.UUID;

public final class AvailabilitySlotDtos {

    private AvailabilitySlotDtos() {
    }

    public record CreateAvailabilitySlotRequest(Instant startsAt, Instant endsAt) {
    }

    public record AvailabilitySlotResponse(UUID id, UUID providerId, Instant startsAt, Instant endsAt,
            AvailabilityStatus status) {
        static AvailabilitySlotResponse from(AvailabilitySlot slot) {
            return new AvailabilitySlotResponse(slot.getId(), slot.getProviderId(), slot.getStartsAt(),
                    slot.getEndsAt(), slot.getStatus());
        }
    }
}
