package com.zairo.factory.booking;

public enum BookingStatus {
    PENDING,
    /**
     * The slot is claimed and the booking exists, but no payment has
     * succeeded yet — every booking starts here (see
     * BookingService.createBooking), not at CONFIRMED. Transitions to
     * CONFIRMED only once PaymentsService.createPayment resolves the
     * charge successfully (synchronously for the mock provider, or later
     * via a verified webhook for a real one — see ADR-0006). A booking
     * left here past {@code booking.payment-timeout-minutes} is cancelled
     * by BookingPaymentTimeoutJob and its slot released.
     */
    PENDING_PAYMENT,
    CONFIRMED,
    CANCELLED,
    COMPLETED,
    /** The customer didn't show up for a CONFIRMED slot — set by the provider owner, not the customer. */
    NO_SHOW
}
