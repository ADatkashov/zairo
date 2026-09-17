package com.zairo.factory.revenueengine;

/**
 * Every revenue-recovery action the Decision Engine can ever choose between
 * — see this package's own doc comment for which of these have a real
 * {@link RevenueStrategy} implementation today (only {@code SMART_FILL},
 * via {@code smartfill.SmartFillStrategy}) versus which exist purely so the
 * outcome ledger/vocabulary is ready for them.
 */
public enum ActionType {
    /** Freed slot -> find and notify likely candidates. Implemented (smart-fill module). */
    SMART_FILL,
    /** Customer's usual visit interval has elapsed -> proactive personal booking offer. Not implemented yet. */
    REBOOK,
    /** Customer has gone quiet well past their usual interval -> win-back campaign. Not implemented yet. */
    CUSTOMER_REACTIVATION,
    /** A schedule gap between two bookings -> actively find something to fill it, not just wait for a cancellation. Not implemented yet. */
    GAP_FILL,
    /** A slot/customer combination unlikely to convert on its own -> a targeted, time-limited discount. Not implemented yet. */
    SMART_PROMOTION,
    /** A booking with elevated no-show risk -> a stronger confirmation flow. Not implemented yet. */
    NO_SHOW_PREVENTION,
    /** A high-LTV customer at risk of churn -> a retention play. Not implemented yet. */
    VIP_RETENTION,
    /** No strategy was applicable, or none had a positive expected value -- recorded so "how often do we have nothing to offer" is measurable too. */
    NO_ACTION,
}
