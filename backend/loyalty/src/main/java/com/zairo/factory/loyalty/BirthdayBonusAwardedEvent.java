package com.zairo.factory.loyalty;

import java.util.UUID;

/**
 * A member just received their birthday bonus. Published inside the awarding transaction; the notifications module
 * listens (AFTER_COMMIT) to tell the customer -- loyalty never depends on notifications, same one-directional pattern
 * as every other domain event here (ADR-0002).
 */
public record BirthdayBonusAwardedEvent(UUID userId, UUID providerId, String providerName, int points) {
}
