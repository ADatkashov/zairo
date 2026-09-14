package com.zairo.factory.loyalty;

public enum LoyaltyRedemptionStatus {
    /** Points spent, code issued, not yet used or expired -- can still be applied or cancelled. */
    ACTIVE,
    /** The business applied this redemption to a specific booking -- terminal, cannot be reused or cancelled. */
    APPLIED,
    /** The customer or business cancelled it before use -- points were refunded. Terminal. */
    CANCELLED,
    /** The redemption's own validity window elapsed unused -- points are not refunded (see LoyaltyRedemptionService). */
    EXPIRED
}
