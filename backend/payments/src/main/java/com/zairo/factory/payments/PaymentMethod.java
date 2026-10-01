package com.zairo.factory.payments;

/**
 * How a payment for a booking was made or should be made.
 * ONLINE payments are processed through FreedomPay or other payment provider.
 * Other methods are recorded offline without provider integration.
 */
public enum PaymentMethod {
    /** Online payment through payment provider (FreedomPay, etc) */
    ONLINE,
    /** Cash payment in person */
    CASH,
    /** Card payment in person or other direct card charge */
    CARD,
    /** Other payment method not covered above */
    OTHER
}
