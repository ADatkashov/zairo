package com.zairo.factory.loyalty;

import java.util.UUID;

/**
 * A business owner just greeted a member by hand. Published inside the sending transaction; notifications listens
 * (AFTER_COMMIT) to deliver it -- loyalty never depends on notifications (ADR-0002). {@code message} is null when the
 * owner kept the default text; {@code points} is 0 for a text-only greeting.
 */
public record ManualGreetingSentEvent(UUID userId, UUID providerId, String providerName, String message, int points) {
}
