package com.zairo.factory.waitlist;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;
import java.util.UUID;

public final class WaitlistDtos {

    private WaitlistDtos() {
    }

    public record JoinWaitlistRequest(
            @Schema(description = "Earliest start the customer wants. Null (with `to` null) means any time.")
            Instant from,
            @Schema(description = "Start times before this instant are wanted. Null means no end.") Instant to) {
    }

    public record WaitlistEntryResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Aigerim Beauty Studio") String providerName,
            Instant from,
            Instant to,
            Instant joinedAt) {
    }
}
