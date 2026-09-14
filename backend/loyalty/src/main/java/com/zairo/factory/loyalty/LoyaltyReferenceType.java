package com.zairo.factory.loyalty;

/**
 * What a {@link LoyaltyTransaction#getReferenceId()} points at. Several
 * values back a partial unique index on {@code loyalty_transaction} (see
 * V57) that makes the earning rule that produces them naturally
 * idempotent -- see this module's own package-info.
 */
public enum LoyaltyReferenceType {
    /** referenceId/bookingId = the booking whose completion earned points. One per booking, enforced by a unique index. */
    BOOKING_EARNING,
    /** referenceId/bookingId = the customer's first completed booking with this business. At most one per account. */
    FIRST_BOOKING_BONUS,
    /** referenceId/bookingId = the qualifying (Nth) completed booking. One per booking, enforced by a unique index. */
    REPEAT_VISIT_BONUS,
    /** referenceId/bookingId = the booking the review was left for. One per booking, enforced by a unique index. */
    REVIEW_BONUS,
    /** referenceId = the {@link LoyaltyMilestoneRule} that was reached. At most once per milestone per account. */
    MILESTONE,
    /** referenceId = the {@link LoyaltyRedemption} that spent the points. */
    REWARD_REDEMPTION,
    /** referenceId = the {@link LoyaltyRedemption} whose spend is being restored. */
    REDEMPTION_REVERSAL,
    /** referenceId = the {@link LoyaltyEarnLot} that expired. */
    LOT_EXPIRATION,
    /** No structured reference -- a free-text manual adjustment; see {@link LoyaltyTransaction#getActorUserId()}. */
    MANUAL_ADJUSTMENT,
    /**
     * referenceId/bookingId = a COMPLETED booking whose payment was later
     * refunded (Phase 0 stabilization) -- claws back that booking's own
     * BOOKING_EARNING points, capped at the account's current balance. At
     * most one per booking, enforced by a unique index (see V59), same
     * idempotency shape as the earning rules it undoes.
     */
    PAYMENT_REFUND_REVERSAL
}
