package com.zairo.factory.auth;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Brute-force protection on {@link AuthService#login} — after {@code
 * app.auth.login-attempt-limit} consecutive failures for one email, further
 * attempts are rejected (429) until {@code app.auth.login-lockout-minutes}
 * passes. In-memory, per-instance: this codebase is a single-instance
 * modular monolith today (ADR-0001) with no shared cache — the right choice
 * once Factory actually runs more than one {@code platform-api} instance is
 * a shared store (Redis, or a DB table), not before it's needed.
 *
 * <p>Keyed by email, not by caller IP — an attacker with many IPs is only
 * slowed by an IP-keyed limiter, while the account itself stays exposed;
 * this protects the account regardless of where the attempts come from, at
 * the cost of being a (much cheaper) denial-of-service vector against one
 * specific victim's login — an accepted tradeoff at this stage, not an
 * oversight.
 *
 * <p><b>Known limitation</b>: the map only shrinks when a record is read
 * again after expiring — an attacker who tries once against many distinct,
 * never-repeated email addresses can grow it unbounded. Not worth a
 * scheduled eviction job before there's a real incident showing it matters.
 */
@Component
class LoginAttemptLimiter {

    private final Map<String, Attempt> attemptsByEmail = new ConcurrentHashMap<>();
    private final int limit;
    private final long lockoutMinutes;

    LoginAttemptLimiter(@Value("${app.auth.login-attempt-limit:5}") int limit,
            @Value("${app.auth.login-lockout-minutes:15}") long lockoutMinutes) {
        this.limit = limit;
        this.lockoutMinutes = lockoutMinutes;
    }

    /** @throws TooManyLoginAttemptsException if this email is currently locked out. */
    void checkNotLockedOut(String email) {
        Attempt attempt = attemptsByEmail.get(normalize(email));
        if (attempt != null && attempt.lockedUntil != null && Instant.now().isBefore(attempt.lockedUntil)) {
            throw new TooManyLoginAttemptsException(
                    "Too many failed login attempts — try again in a few minutes");
        }
    }

    /** Locks the account out once {@code limit} consecutive failures are reached; a lapsed lockout starts over. */
    void recordFailure(String email) {
        String key = normalize(email);
        attemptsByEmail.compute(key, (ignored, existing) -> {
            Instant now = Instant.now();
            boolean expired = existing == null || (existing.lockedUntil != null && now.isAfter(existing.lockedUntil));
            int failures = expired ? 1 : existing.failures + 1;
            Instant lockedUntil = failures >= limit ? now.plusSeconds(lockoutMinutes * 60) : null;
            return new Attempt(failures, lockedUntil);
        });
    }

    void recordSuccess(String email) {
        attemptsByEmail.remove(normalize(email));
    }

    private static String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }

    private record Attempt(int failures, Instant lockedUntil) {
    }
}
