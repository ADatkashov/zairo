package com.zairo.factory.search;

import java.util.UUID;

/**
 * Published after every {@code /search/providers} call, whether or not
 * anything matched — no listener consumes this yet (see the discovery
 * ADR's analytics-hooks section). {@code resultCount} is the total match
 * count, not just what fit on the requested page.
 */
public record SearchPerformedEvent(String vertical, UUID businessTypeId, String query, int resultCount) {
}
