package com.zairo.factory.customerintelligence;

/**
 * Which part of the day a customer's completed bookings cluster around --
 * bucketed from each visit's {@code AvailabilitySlot.startsAt} hour in UTC,
 * same "minute/hour of day in UTC" convention {@code
 * smartfill.CandidateFinder#minuteOfDayUtc} already uses for its own
 * time-of-day signal.
 */
public enum PreferredTimeRange {
    MORNING,
    AFTERNOON,
    EVENING,
    NIGHT,
    /** No completed booking yet to infer a pattern from. */
    UNKNOWN;

    /** @param hourOfDayUtc 0-23. */
    static PreferredTimeRange fromHourOfDayUtc(int hourOfDayUtc) {
        if (hourOfDayUtc >= 5 && hourOfDayUtc < 12) {
            return MORNING;
        }
        if (hourOfDayUtc >= 12 && hourOfDayUtc < 17) {
            return AFTERNOON;
        }
        if (hourOfDayUtc >= 17 && hourOfDayUtc < 21) {
            return EVENING;
        }
        return NIGHT;
    }
}
