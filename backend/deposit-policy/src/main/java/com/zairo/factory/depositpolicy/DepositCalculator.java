package com.zairo.factory.depositpolicy;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Calculate the deposit amount based on the payment settings and booking total.
 */
public class DepositCalculator {

    private DepositCalculator() {
    }

    /**
     * Calculate the deposit amount required for a booking.
     *
     * @param totalAmount total booking amount
     * @param depositType type of deposit required
     * @param depositValueType type of value (percentage or fixed) - only used for DEPOSIT type
     * @param depositValue the value - only used for DEPOSIT type
     * @return the deposit amount that must be paid
     */
    public static BigDecimal calculateDepositAmount(BigDecimal totalAmount, DepositType depositType,
            DepositValueType depositValueType, BigDecimal depositValue) {

        if (depositType == null || depositType == DepositType.NO_PAYMENT) {
            return BigDecimal.ZERO;
        }

        if (depositType == DepositType.FULL_PAYMENT) {
            return totalAmount;
        }

        if (depositType == DepositType.DEPOSIT) {
            if (depositValueType == null || depositValue == null) {
                return BigDecimal.ZERO;
            }

            if (depositValueType == DepositValueType.PERCENTAGE) {
                BigDecimal percentage = depositValue.divide(new BigDecimal(100), 4, RoundingMode.HALF_UP);
                return totalAmount.multiply(percentage).setScale(2, RoundingMode.HALF_UP);
            } else if (depositValueType == DepositValueType.FIXED_AMOUNT) {
                // Fixed amount, cap at total if needed
                return depositValue.min(totalAmount).setScale(2, RoundingMode.HALF_UP);
            }
        }

        return BigDecimal.ZERO;
    }
}
