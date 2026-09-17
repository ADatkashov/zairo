package com.zairo.factory.loyalty;

/** Every possible reason a {@link LoyaltyAccount} balance changes -- see LoyaltyTransaction. */
public enum LoyaltyTransactionType {
    /** A points-earning rule fired (booking completion, first booking, repeat visit, review, milestone). */
    EARNED,
    /** A discretionary/one-off award that isn't one of the standard earning rules (e.g. a campaign bonus). */
    BONUS,
    /** Points spent redeeming a {@link LoyaltyReward}. */
    REDEEMED,
    /** Points that reached their {@link LoyaltyEarnLot#getExpiresAt()} unused. */
    EXPIRED,
    /** Points restored after a redemption was cancelled/refunded. */
    REFUND,
    /** A manual correction by an authorized business/admin actor -- always carries a reason and an actor. */
    ADJUSTMENT,
    /** The exact inverse of an earlier transaction (e.g. undoing a mistaken award) -- never edits the original row. */
    REVERSAL
}
