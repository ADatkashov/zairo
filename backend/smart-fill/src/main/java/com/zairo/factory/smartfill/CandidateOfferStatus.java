package com.zairo.factory.smartfill;

public enum CandidateOfferStatus {
    /** Picked and scored, but its stage hasn't been sent yet. */
    PENDING,
    /** Its stage was sent -- the notification is out. */
    NOTIFIED,
    /** The customer opened/listed their offers and saw this one (see SmartFillController#list). */
    VIEWED,
    /** The customer booked the slot through this offer. */
    ACCEPTED,
    /**
     * Reserved: no endpoint sets this today (a customer either books or
     * ignores the offer) -- see NotificationPolicy's decline-cooldown for
     * where this would plug in once an explicit "not interested" action
     * exists.
     */
    DECLINED,
    /** The campaign expired (no one booked, ever) while this offer was still PENDING/NOTIFIED/VIEWED. */
    EXPIRED,
    /** The slot was booked by a different candidate (or a non-candidate entirely) -- this offer is moot. */
    CANCELLED,
}
