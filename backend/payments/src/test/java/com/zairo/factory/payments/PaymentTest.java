package com.zairo.factory.payments;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zairo.factory.paymentprovider.PaymentProviderName;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit test of the Payment state changes -- no Spring context, no database. */
class PaymentTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T10:05:00Z");

    private static Payment payment() {
        return new Payment(UUID.randomUUID(), UUID.randomUUID(), new BigDecimal("5000"), "KZT",
                PaymentProviderName.MOCK, T0);
    }

    @Test
    void newPaymentIsCreatedOnlineAndKeysItsIdempotencyOnItsOwnId() {
        Payment p = payment();

        assertThat(p.getStatus()).isEqualTo(PaymentStatus.CREATED);
        assertThat(p.getPaymentMethod()).isEqualTo(PaymentMethod.ONLINE);
        assertThat(p.getIdempotencyKey()).isEqualTo(p.getId());
        assertThat(p.getAmount()).isEqualByComparingTo("5000");
        assertThat(p.getCurrency()).isEqualTo("KZT");
        assertThat(p.getRefundAttempts()).isZero();
        assertThat(p.isSaveCard()).isFalse();
    }

    @Test
    void paymentMethodIsRequired() {
        assertThatThrownBy(() -> new Payment(UUID.randomUUID(), UUID.randomUUID(), BigDecimal.TEN, "KZT",
                PaymentProviderName.MOCK, null, T0)).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void invalidMoneyIsRejectedAtCreation() {
        assertThatThrownBy(() -> new Payment(UUID.randomUUID(), UUID.randomUUID(), new BigDecimal("-1"), "KZT",
                PaymentProviderName.MOCK, T0)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new Payment(UUID.randomUUID(), UUID.randomUUID(), BigDecimal.TEN, "NOPE",
                PaymentProviderName.MOCK, T0)).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void pendingKeepsTheProviderReferenceAndCheckoutUrl() {
        Payment p = payment();

        p.markPending("prov-1", "https://pay.example/checkout", T1);

        assertThat(p.getStatus()).isEqualTo(PaymentStatus.PENDING);
        assertThat(p.getProviderReference()).isEqualTo("prov-1");
        assertThat(p.getCheckoutUrl()).isEqualTo("https://pay.example/checkout");
    }

    @Test
    void successDropsTheCheckoutUrl() {
        Payment p = payment();
        p.markPending("prov-1", "https://pay.example/checkout", T0);

        p.markSucceeded("prov-1", T1);

        assertThat(p.getStatus()).isEqualTo(PaymentStatus.SUCCEEDED);
        assertThat(p.getCheckoutUrl()).isNull();
        assertThat(p.getProviderReference()).isEqualTo("prov-1");
    }

    @Test
    void failureKeepsTheReasonAndDropsTheCheckoutUrl() {
        Payment p = payment();
        p.markPending("prov-1", "https://pay.example/checkout", T0);

        p.markFailed("card declined", T1);

        assertThat(p.getStatus()).isEqualTo(PaymentStatus.FAILED);
        assertThat(p.getFailureReason()).isEqualTo("card declined");
        assertThat(p.getCheckoutUrl()).isNull();
    }

    @Test
    void refundFlowClearsTheFailureReasonOnceRefunded() {
        Payment p = payment();
        p.markSucceeded("prov-1", T0);

        p.markRefundPending(T1);
        assertThat(p.getStatus()).isEqualTo(PaymentStatus.REFUND_PENDING);

        p.markRefundFailed("provider timeout", T1);
        assertThat(p.getStatus()).isEqualTo(PaymentStatus.REFUND_FAILED);
        assertThat(p.getRefundFailureReason()).isEqualTo("provider timeout");

        p.markRefunded(T1);
        assertThat(p.getStatus()).isEqualTo(PaymentStatus.REFUNDED);
        assertThat(p.getRefundFailureReason()).isNull();
    }

    @Test
    void everyFailedRefundCountsAsAnAttempt() {
        Payment p = payment();

        p.markRefundFailed("timeout", T0);
        p.markRefundFailed("timeout again", T1);

        assertThat(p.getRefundAttempts()).isEqualTo(2);
    }

    @Test
    void updatesAreStampedWithTheGivenTime() {
        Payment p = payment();

        p.markSucceeded("prov-1", T1);

        assertThat(p.getCreatedAt()).isEqualTo(T0);
    }
}
