package com.zairo.factory.loyalty;

/** Which durable event a {@link LoyaltyOutboxEvent} row replays -- see that class's own doc comment. */
enum LoyaltyOutboxEventType {
    BOOKING_COMPLETED,
    REVIEW_CREATED,
    /** A COMPLETED booking's payment was refunded after the fact -- see {@code LoyaltyRefundListener}. */
    PAYMENT_REFUNDED
}
