package com.zairo.factory.waitlist;

import java.time.Instant;
import java.util.UUID;

/**
 * Published once per waiting customer when a time they were waiting for opens up (their entry is removed in the same
 * transaction — one nudge, then it is up to them). Consumer: notifications.
 */
public record WaitlistSlotOpenedEvent(UUID userId, UUID providerId, Instant startsAt) {
}
