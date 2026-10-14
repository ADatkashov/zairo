package com.zairo.factory.payments;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PaymentPartialRefundTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T10:05:00Z");

    private static PaymentPartialRefund refund() {
        return new PaymentPartialRefund(UUID.randomUUID(), UUID.randomUUID(), new BigDecimal("1500"), "KZT",
                new BigDecimal("150"), T0);
    }

    @Test
    void newRefundIsPendingWithNoAttemptsAndRetryable() {
        PaymentPartialRefund r = refund();

        assertThat(r.getStatus()).isEqualTo(PaymentPartialRefund.Status.PENDING);
        assertThat(r.getAttempts()).isZero();
        assertThat(r.isRetryable()).isTrue();
        assertThat(r.getAmount()).isEqualByComparingTo("1500");
        assertThat(r.getPlatformFeeReturned()).isEqualByComparingTo("150");
    }

    @Test
    void failureCountsAnAttemptAndStaysRetryableUntilTheLimit() {
        PaymentPartialRefund r = refund();

        for (int i = 1; i < PaymentPartialRefund.MAX_ATTEMPTS; i++) {
            r.markFailed("timeout", T1);
            assertThat(r.getAttempts()).isEqualTo(i);
            assertThat(r.isRetryable()).isTrue();
        }

        r.markFailed("timeout", T1);
        assertThat(r.getAttempts()).isEqualTo(PaymentPartialRefund.MAX_ATTEMPTS);
        assertThat(r.getStatus()).isEqualTo(PaymentPartialRefund.Status.FAILED);
        assertThat(r.isRetryable()).isFalse();
    }

    @Test
    void aRefundedItemIsNeverRetried() {
        PaymentPartialRefund r = refund();
        r.markFailed("timeout", T0);

        r.markRefunded(T1);

        assertThat(r.getStatus()).isEqualTo(PaymentPartialRefund.Status.REFUNDED);
        assertThat(r.getLastError()).isNull();
        assertThat(r.isRetryable()).isFalse();
    }

    @Test
    void longErrorsAreTruncatedToAThousandCharacters() {
        PaymentPartialRefund r = refund();

        r.markFailed("x".repeat(5000), T1);

        assertThat(r.getLastError()).hasSize(1000);
    }

    @Test
    void aNullErrorIsKept() {
        PaymentPartialRefund r = refund();

        r.markFailed(null, T1);

        assertThat(r.getLastError()).isNull();
        assertThat(r.getAttempts()).isEqualTo(1);
    }
}
