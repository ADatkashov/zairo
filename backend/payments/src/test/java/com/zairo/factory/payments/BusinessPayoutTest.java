package com.zairo.factory.payments;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class BusinessPayoutTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T10:05:00Z");

    private static BusinessPayout payout() {
        return new BusinessPayout(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                new BigDecimal("4500"), "KZT", T0);
    }

    @Test
    void newPayoutIsPayable() {
        BusinessPayout p = payout();

        assertThat(p.getStatus()).isEqualTo(BusinessPayoutStatus.PAYABLE);
        assertThat(p.getAmount()).isEqualByComparingTo("4500");
        assertThat(p.getCurrency()).isEqualTo("KZT");
        assertThat(p.getSettledAt()).isNull();
    }

    @Test
    void paidRecordsTheReferenceAndSettlementTime() {
        BusinessPayout p = payout();
        p.markProcessing(T0);

        p.markPaid("bank-123", T1);

        assertThat(p.getStatus()).isEqualTo(BusinessPayoutStatus.PAID);
        assertThat(p.getProviderReference()).isEqualTo("bank-123");
        assertThat(p.getSettledAt()).isEqualTo(T1);
        assertThat(p.getFailureReason()).isNull();
    }

    @Test
    void aFailedPayoutCanBeRetriedAndLaterPaid() {
        BusinessPayout p = payout();
        p.markFailed("bank unavailable", T0);
        assertThat(p.getStatus()).isEqualTo(BusinessPayoutStatus.FAILED);
        assertThat(p.getFailureReason()).isEqualTo("bank unavailable");

        p.markProcessing(T1);
        p.markPaid("bank-456", T1);

        assertThat(p.getStatus()).isEqualTo(BusinessPayoutStatus.PAID);
        assertThat(p.getFailureReason()).isNull();
    }

    @Test
    void aPaidPayoutIsTerminal() {
        BusinessPayout p = payout();
        p.markPaid("bank-123", T0);

        assertThatThrownBy(() -> p.markProcessing(T1)).isInstanceOf(PaymentConflictException.class);
        assertThatThrownBy(() -> p.markFailed("late failure", T1)).isInstanceOf(PaymentConflictException.class);
        assertThatThrownBy(() -> p.markPaid("bank-999", T1)).isInstanceOf(PaymentConflictException.class);
        assertThat(p.getProviderReference()).isEqualTo("bank-123");
    }
}
