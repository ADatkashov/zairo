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
    /** The owner cancelled the campaign -- terminal (see {@code campaigncenter}'s Campaign Center). */
    CANCELLED,
    /**
     * The owner paused notification staging -- only reachable from NOTIFYING
     * (see {@link SmartFillCampaignService#pauseCampaign}). Excluded from
     * {@link SmartFillCampaignJob}'s sweep (which filters on NOTIFYING
     * specifically) so no further stage is sent while paused, but still
     * included wherever an active campaign must be closed out if its slot
     * gets booked anyway (see {@link SmartFillCampaignService
     * #completeCampaignsForBookedSlot}).
     */
    PAUSED,
}
