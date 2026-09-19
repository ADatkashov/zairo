package com.zairo.factory.payments;

import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** The "amount mismatch detection" / "zero/negative protection" fail-fast guards from PaymentAllocation's constructor. */
class PaymentAllocationTest {

    @Test
    void rejectsASplitThatDoesNotAddUpToTheOriginalAmount() {
        assertThrows(IllegalStateException.class, () -> new PaymentAllocation(UUID.randomUUID(),
                new BigDecimal("15000.00"), new BigDecimal("13500.00"), new BigDecimal("1400.00"), "KZT",
                new BigDecimal("0.10"), Instant.now()));
    }

    @Test
    void rejectsANegativeBusinessAmount() {
        assertThrows(IllegalArgumentException.class, () -> new PaymentAllocation(UUID.randomUUID(),
                new BigDecimal("15000.00"), new BigDecimal("-100.00"), new BigDecimal("15100.00"), "KZT",
                new BigDecimal("0.10"), Instant.now()));
    }

    @Test
    void acceptsASplitThatAddsUpExactly() {
        PaymentAllocation allocation = new PaymentAllocation(UUID.randomUUID(), new BigDecimal("15000.00"),
                new BigDecimal("13500.00"), new BigDecimal("1500.00"), "KZT", new BigDecimal("0.10"), Instant.now());
        org.junit.jupiter.api.Assertions.assertEquals(new BigDecimal("13500.00"), allocation.getBusinessAmount());
        org.junit.jupiter.api.Assertions.assertEquals(new BigDecimal("1500.00"), allocation.getPlatformFee());
    }
}
