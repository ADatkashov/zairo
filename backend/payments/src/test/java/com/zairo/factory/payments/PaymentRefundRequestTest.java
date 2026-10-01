package com.zairo.factory.payments;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * {@link PaymentRefundRequest}'s state machine in isolation -- no Spring, no
 * database, same "plain entity unit test" convention as {@code
 * loyalty.LoyaltyEarnLotTest}/{@code LoyaltyRewardTest}. This is where the
 * actual claim/retry/terminal-state correctness lives; {@code
 * PaymentRefundOutboxItemProcessor}'s own transactional methods are thin
 * wrappers around these that this codebase has no precedent for unit-
 * testing without a real database (see {@code PaymentRefundOutboxApiTests}
 * for the Testcontainers-backed integration coverage instead).
 */
class PaymentRefundRequestTest {

    private static final UUID PAYMENT_ID = UUID.randomUUID();
    private static final UUID BOOKING_ID = UUID.randomUUID();

    @Test
    void constructionStartsPendingAndImmediatelyDue() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);

        assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.PENDING);
        assertThat(request.getAttempts()).isZero();
        assertThat(request.getNextAttemptAt()).isEqualTo(now);
        assertThat(request.isClaimable(now)).isTrue();
    }

    @Test
    void pendingIsClaimableAssoonAsItExists() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);

        // A fresh PENDING row is due right away -- nextAttemptAt == now,
        // and isClaimable's "not after now" check includes equality.
        assertThat(request.isClaimable(now)).isTrue();
        assertThat(request.isClaimable(now.minusSeconds(1))).isFalse();
    }

    @Test
    void processingIsNotClaimableWhileFresh() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);
        request.markProcessing(now);

        assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.PROCESSING);
        assertThat(request.isClaimable(now)).isFalse();
        assertThat(request.isClaimable(now.plus(1, ChronoUnit.MINUTES))).isFalse();
    }

    @Test
    void staleProcessingBecomesClaimableAgainPastTheThreshold_restartRecovery() {
        Instant claimedAt = Instant.now();
        PaymentRefundRequest request = newRequest(claimedAt);
        request.markProcessing(claimedAt);

        // Just under the threshold: still treated as a genuinely in-flight
        // attempt, not abandoned.
        Instant justBefore = claimedAt.plus(PaymentRefundRequest.STALE_PROCESSING_THRESHOLD).minusSeconds(1);
        assertThat(request.isClaimable(justBefore)).isFalse();

        // Past it: a worker that crashed mid-call left this behind -- a
        // fresh claim attempt must be able to pick it back up (see
        // PaymentRefundOutboxItemProcessor#claim).
        Instant justAfter = claimedAt.plus(PaymentRefundRequest.STALE_PROCESSING_THRESHOLD).plusSeconds(1);
        assertThat(request.isClaimable(justAfter)).isTrue();
    }

    @Test
    void succeededIsTerminal_neverClaimableAgain() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);
        request.markProcessing(now);
        request.markSucceeded(now);

        assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.SUCCEEDED);
        assertThat(request.getProcessingStartedAt()).isNull();
        // Not claimable at any point in time, ever -- not "now", not the
        // far future, not a stale-processing lookalike.
        assertThat(request.isClaimable(now)).isFalse();
        assertThat(request.isClaimable(now.plus(365, ChronoUnit.DAYS))).isFalse();
    }

    @Test
    void failedIsTerminal_neverClaimableAgain() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);
        request.markProcessing(now);
        request.markFailedPermanently(now);

        assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.FAILED);
        assertThat(request.getProcessingStartedAt()).isNull();
        assertThat(request.isClaimable(now)).isFalse();
        assertThat(request.isClaimable(now.plus(365, ChronoUnit.DAYS))).isFalse();
    }

    @Test
    void recordFailureSchedulesExponentialBackoffCappedAtThirtyMinutes() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);
        request.markProcessing(now);

        long[] expectedSeconds = {30, 60, 120, 240, 480, 960, 1800, 1800};
        for (long expected : expectedSeconds) {
            request.markProcessing(now); // re-claim for the next attempt, same as the worker would
            request.recordFailure("simulated provider outage", now);
            assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.RETRY);
            assertThat(request.getNextAttemptAt()).isEqualTo(now.plusSeconds(expected));
            assertThat(request.getProcessingStartedAt()).isNull();
        }
        assertThat(request.getAttempts()).isEqualTo(expectedSeconds.length);
    }

    @Test
    void retryIsNotClaimableUntilItsBackoffElapses() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);
        request.markProcessing(now);
        request.recordFailure("timeout", now);

        assertThat(request.isClaimable(now.plusSeconds(29))).isFalse();
        assertThat(request.isClaimable(now.plusSeconds(30))).isTrue();
    }

    @Test
    void attemptsReachMaxAttemptsAfterExactlyThatManyFailures() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);

        for (int i = 1; i <= PaymentRefundRequest.MAX_ATTEMPTS; i++) {
            request.markProcessing(now);
            request.recordFailure("attempt " + i + " failed", now);
            assertThat(request.getAttempts()).isEqualTo(i);
        }
        // Exactly at the threshold -- the item processor's own job (not
        // this entity's) is deciding to call markFailedPermanently once
        // getAttempts() >= MAX_ATTEMPTS; this only proves the counter
        // reaches that boundary at the right attempt, not one before or after.
        assertThat(request.getAttempts()).isEqualTo(PaymentRefundRequest.MAX_ATTEMPTS);
        assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.RETRY); // still retryable per se

        request.markFailedPermanently(now);
        assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.FAILED);
    }

    @Test
    void lastErrorIsTruncatedToOneThousandCharacters() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);
        request.markProcessing(now);

        request.recordFailure("x".repeat(2000), now);

        assertThat(request.getLastError()).hasSize(1000);
    }

    @Test
    void aNullFailureReasonIsRecordedAsNull() {
        Instant now = Instant.now();
        PaymentRefundRequest request = newRequest(now);
        request.markProcessing(now);

        request.recordFailure(null, now);

        assertThat(request.getLastError()).isNull();
        assertThat(request.getStatus()).isEqualTo(PaymentRefundRequestStatus.RETRY);
    }

    private static PaymentRefundRequest newRequest(Instant now) {
        return new PaymentRefundRequest(UUID.randomUUID(), PAYMENT_ID, BOOKING_ID, new BigDecimal("35.00"), "USD",
                com.zairo.factory.paymentprovider.PaymentProviderName.MOCK, "mock_pi_test", now);
    }
}
