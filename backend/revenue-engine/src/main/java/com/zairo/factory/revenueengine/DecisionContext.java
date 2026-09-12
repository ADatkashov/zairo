package com.zairo.factory.revenueengine;

import java.time.Instant;
import java.util.UUID;

/**
 * What triggered a decision, generic across every {@link DecisionTrigger} —
 * {@code referenceId}'s meaning depends on the trigger (for {@code
 * BOOKING_CANCELLED}, the cancelled booking's id) and is interpreted only by
 * each {@link RevenueStrategy}, never by {@link DecisionEngine} itself. Kept
 * intentionally thin (no denormalized business data) so a new trigger never
 * needs a new context shape — a strategy that needs more than an id looks
 * the rest up itself, the same way {@code smartfill.SmartFillStrategy}
 * re-resolves the booking/slot it's given a bare id for.
 */
public record DecisionContext(DecisionTrigger trigger, UUID providerId, UUID referenceId, Instant occurredAt) {
}
