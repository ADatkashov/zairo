package com.zairo.factory.booking;

public enum BookingStatus {
    PENDING,
    CONFIRMED,
    CANCELLED,
    COMPLETED,
    /** The customer didn't show up for a CONFIRMED slot — set by the provider owner, not the customer. */
    NO_SHOW
}
