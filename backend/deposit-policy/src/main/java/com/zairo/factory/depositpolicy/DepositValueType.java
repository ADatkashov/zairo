package com.zairo.factory.depositpolicy;

/**
 * When deposit type is DEPOSIT, how is the deposit amount calculated?
 * PERCENTAGE: depositValue is a percentage of the total booking amount
 * FIXED_AMOUNT: depositValue is a fixed amount in the booking's currency
 */
public enum DepositValueType {
    PERCENTAGE,
    FIXED_AMOUNT
}
