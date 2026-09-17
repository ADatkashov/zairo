package com.zairo.factory.loyalty;

/** Lifecycle of one {@link LoyaltyOutboxEvent} row -- see that class's own doc comment. */
enum LoyaltyOutboxEventStatus {
    PENDING,
    PROCESSED,
    /** Gave up after {@link LoyaltyOutboxProcessor#MAX_ATTEMPTS} failed attempts -- a permanent, not transient, failure. */
    FAILED
}
