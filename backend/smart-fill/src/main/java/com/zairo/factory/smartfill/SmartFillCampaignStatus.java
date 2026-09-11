package com.zairo.factory.smartfill;

public enum SmartFillCampaignStatus {
    /** Just created, no candidates found/scored yet -- transient, moves on within the same transaction. */
    CREATED,
    /** Candidate pool built and scored; no stage has gone out yet. */
    SEARCHING,
    /** At least one stage of offers has been sent; waiting to see if the slot gets booked or the next stage is due. */
    NOTIFYING,
    /** The slot was booked (by a candidate or anyone else) -- terminal, success. */
    BOOKED,
    /** No candidates found, or every stage was exhausted / the slot's start time passed with no booking -- terminal. */
    EXPIRED,
    /** Reserved for a future manual/admin abort -- no code path sets this yet. */
    CANCELLED,
}
