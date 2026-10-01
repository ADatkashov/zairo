package com.zairo.factory.payments;

import static org.junit.jupiter.api.Assertions.*;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class DepositCalculatorTest {

    @Test
    void testNoPaymentRequired() {
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("1000"), DepositType.NO_PAYMENT, null, null);
        assertEquals(BigDecimal.ZERO, amount);
    }

    @Test
    void testFullPaymentRequired() {
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("1000"), DepositType.FULL_PAYMENT, null, null);
        assertEquals(new BigDecimal("1000"), amount);
    }

    @Test
    void testDepositPercentage() {
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("1000"), DepositType.DEPOSIT, DepositValueType.PERCENTAGE, new BigDecimal("30"));
        assertEquals(new BigDecimal("300.00"), amount);
    }

    @Test
    void testDepositPercentageRounding() {
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("50000"), DepositType.DEPOSIT, DepositValueType.PERCENTAGE, new BigDecimal("33"));
        assertEquals(new BigDecimal("16500.00"), amount);
    }

    @Test
    void testDepositFixedAmount() {
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("1000"), DepositType.DEPOSIT, DepositValueType.FIXED_AMOUNT, new BigDecimal("200"));
        assertEquals(new BigDecimal("200.00"), amount);
    }

    @Test
    void testDepositFixedAmountCapAtTotal() {
        // Fixed amount greater than total should be capped at total
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("1000"), DepositType.DEPOSIT, DepositValueType.FIXED_AMOUNT, new BigDecimal("5000"));
        assertEquals(new BigDecimal("1000.00"), amount);
    }

    @Test
    void testZeroPercentageDeposit() {
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("1000"), DepositType.DEPOSIT, DepositValueType.PERCENTAGE, new BigDecimal("0"));
        assertEquals(BigDecimal.ZERO, amount);
    }

    @Test
    void testHundredPercentageDeposit() {
        BigDecimal amount = DepositCalculator.calculateDepositAmount(
                new BigDecimal("1000"), DepositType.DEPOSIT, DepositValueType.PERCENTAGE, new BigDecimal("100"));
        assertEquals(new BigDecimal("1000.00"), amount);
    }
}
