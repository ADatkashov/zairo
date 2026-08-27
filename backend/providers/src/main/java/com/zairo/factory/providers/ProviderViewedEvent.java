package com.zairo.factory.providers;

import java.util.UUID;

/**
 * Published on every {@code GET /providers/{id}} — no listener consumes
 * this yet (see the discovery ADR's analytics-hooks section). {@code
 * viewerUserId} is null for an unauthenticated view (this endpoint doesn't
 * require auth), not omitted — a future "who's looking" metric still needs
 * to count anonymous views, not silently drop them.
 */
public record ProviderViewedEvent(UUID providerId, UUID viewerUserId) {
}
