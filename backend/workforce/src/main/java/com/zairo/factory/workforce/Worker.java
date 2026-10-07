package com.zairo.factory.workforce;

import java.util.UUID;

/**
 * A person who serves customers at one business, whichever directory they were added through. {@code userId}
 * links the same human across businesses (and across kinds); null for a person typed in by hand.
 */
public record Worker(WorkerKind kind, UUID id, UUID providerId, UUID userId, String displayName, String photoUrl,
        boolean active) {
}
