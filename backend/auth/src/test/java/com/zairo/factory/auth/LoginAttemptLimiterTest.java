package com.zairo.factory.auth;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class LoginAttemptLimiterTest {

    @Test
    void staysUnlockedBelowTheFailureLimit() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(3, 15);
        limiter.recordFailure("a@example.com");
        limiter.recordFailure("a@example.com");

        assertDoesNotThrow(() -> limiter.checkNotLockedOut("a@example.com"));
    }

    @Test
    void locksOutOnceTheLimitIsReached() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(3, 15);
        limiter.recordFailure("a@example.com");
        limiter.recordFailure("a@example.com");
        limiter.recordFailure("a@example.com");

        assertThrows(TooManyLoginAttemptsException.class, () -> limiter.checkNotLockedOut("a@example.com"));
    }

    @Test
    void isKeyedPerAccountNotGlobally() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(1, 15);
        limiter.recordFailure("locked@example.com");

        assertThrows(TooManyLoginAttemptsException.class, () -> limiter.checkNotLockedOut("locked@example.com"));
        assertDoesNotThrow(() -> limiter.checkNotLockedOut("other@example.com"));
    }

    @Test
    void isCaseInsensitiveOnEmail() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(1, 15);
        limiter.recordFailure("Someone@Example.com");

        assertThrows(TooManyLoginAttemptsException.class, () -> limiter.checkNotLockedOut("someone@example.com"));
    }

    @Test
    void aSuccessClearsThePriorFailureCount() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(2, 15);
        limiter.recordFailure("a@example.com");
        limiter.recordSuccess("a@example.com");
        limiter.recordFailure("a@example.com");

        // Only one failure since the reset — still below the limit of 2.
        assertDoesNotThrow(() -> limiter.checkNotLockedOut("a@example.com"));
    }

    @Test
    void aZeroMinuteLockoutIsEffectivelyAlreadyExpiredOnTheNextCheck() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(1, 0);
        limiter.recordFailure("a@example.com");

        assertDoesNotThrow(() -> limiter.checkNotLockedOut("a@example.com"));
    }
}
