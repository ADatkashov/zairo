package com.zairo.factory.depositpolicy;

/**
 * Type of deposit required for a booking.
 * NO_PAYMENT: no advance payment required
 * FULL_PAYMENT: full amount must be paid upfront
 * DEPOSIT: only a portion (percentage or fixed amount) is required upfront
 */
public enum DepositType {
    NO_PAYMENT,
    FULL_PAYMENT,
    DEPOSIT
}
