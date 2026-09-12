package com.zairo.factory.reactivationengine;

public enum ReactivationCampaignStatus {
    /** The win-back nudge has been sent; waiting to see if the customer books again before {@code expiresAt}. */
    SENT,
    /** The customer booked again with this provider before the follow-up window closed -- terminal, success. */
    BOOKED,
    /** The follow-up window closed with no rebooking -- terminal. */
    EXPIRED,
}
