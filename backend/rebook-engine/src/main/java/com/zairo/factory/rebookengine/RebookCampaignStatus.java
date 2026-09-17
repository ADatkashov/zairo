package com.zairo.factory.rebookengine;

public enum RebookCampaignStatus {
    /** Just created; waiting for {@code dueAt} (the customer's predicted next-visit date) before nudging. */
    CREATED,
    /** The nudge has been sent; waiting to see if the customer books again before {@code expiresAt}. */
    OFFERED,
    /** The customer booked again with this provider before the follow-up window closed -- terminal, success. */
    BOOKED,
    /** The follow-up window closed with no rebooking -- terminal. */
    EXPIRED,
    /** The owner cancelled the campaign -- terminal (see {@code campaigncenter}'s Campaign Center). */
    CANCELLED,
}
