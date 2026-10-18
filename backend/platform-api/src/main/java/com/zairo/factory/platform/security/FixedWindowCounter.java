package com.zairo.factory.platform.security;

import java.time.Clock;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Counts hits per key inside a fixed time window. In-memory and per instance,
 * like {@code LoginAttemptLimiter}: right for the single-instance monolith
 * (ADR-0001); a second instance needs a shared store.
 *
 * <p>The map is swept of expired windows whenever it grows past
 * {@link #SWEEP_THRESHOLD}, so an attacker cycling through endless keys
 * cannot grow it without bound.
 */
final class FixedWindowCounter {

    static final int SWEEP_THRESHOLD = 10_000;

    record Result(boolean allowed, long retryAfterSeconds) {
    }

    private record Window(long startMillis, int count) {
    }

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final Clock clock;

    FixedWindowCounter(Clock clock) {
        this.clock = clock;
    }

    /** Records one hit for {@code key}; not allowed once {@code limit} hits already happened in the window. */
    Result hit(String key, int limit, long windowSeconds) {
        long now = clock.millis();
        long windowMillis = windowSeconds * 1000;
        if (windows.size() > SWEEP_THRESHOLD) {
            windows.values().removeIf(w -> now - w.startMillis() >= windowMillis);
        }
        Window updated = windows.compute(key, (k, existing) -> {
            if (existing == null || now - existing.startMillis() >= windowMillis) {
                return new Window(now, 1);
            }
            return new Window(existing.startMillis(), existing.count() + 1);
        });
        if (updated.count() <= limit) {
            return new Result(true, 0);
        }
        long retryAfterMillis = updated.startMillis() + windowMillis - now;
        return new Result(false, Math.max(1, (retryAfterMillis + 999) / 1000));
    }

    int trackedKeys() {
        return windows.size();
    }
}
