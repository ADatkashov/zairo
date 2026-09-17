package com.zairo.factory.loyalty;

/** What redeeming a {@link LoyaltyReward} actually gets a customer. */
public enum LoyaltyRewardType {
    /** A fixed currency amount off -- see {@link LoyaltyReward#getDiscountAmount()}. */
    FIXED_DISCOUNT,
    /** A percentage off -- see {@link LoyaltyReward#getDiscountPercentage()}. */
    PERCENTAGE_DISCOUNT,
    /** A specific service, free -- see {@link LoyaltyReward#getServiceId()}. */
    FREE_SERVICE,
    /** A business-defined reward with no fixed monetary shape -- applied manually by the business (see terms). */
    CUSTOM
}
