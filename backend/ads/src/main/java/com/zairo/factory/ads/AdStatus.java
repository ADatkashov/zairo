package com.zairo.factory.ads;

/**
 * Lifecycle of a banner. Only {@link #ACTIVE} banners inside their date window
 * are shown (see {@link AdBanner#isLiveAt}); "ended" is not a status, it is
 * {@code endsAt} being in the past.
 */
public enum AdStatus {

    /** Being prepared; never shown. */
    DRAFT,

    /** Submitted (step 2: after payment) and waiting for a moderator. */
    PENDING_REVIEW,

    /** Approved; shown while inside its date window. */
    ACTIVE,

    /** Taken off by an admin without rejecting it; can be reactivated. */
    PAUSED,

    /** Refused by a moderator; carries a reason. Can be edited and resubmitted. */
    REJECTED
}
