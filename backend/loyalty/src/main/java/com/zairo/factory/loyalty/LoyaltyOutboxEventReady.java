package com.zairo.factory.loyalty;

import java.util.UUID;

/**
 * Published (in-process, same transaction) right after a {@link
 * LoyaltyOutboxEvent} row is written, so {@link LoyaltyOutboxProcessor} can
 * try it eagerly, right after commit, instead of waiting for its next
 * scheduled sweep -- see that class's own doc comment. Purely a latency
 * optimization for the common case: the outbox row itself (not this event)
 * is what guarantees the earning is never lost, since this event is just as
 * in-memory/best-effort as the old AFTER_COMMIT listener this module used
 * to rely on exclusively.
 */
record LoyaltyOutboxEventReady(UUID outboxEventId) {
}
