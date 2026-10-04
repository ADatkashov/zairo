package com.zairo.factory.loyalty;

import java.time.LocalDate;
import java.time.Month;

/**
 * Birthday arithmetic shared by the daily bonus sweep and the business's "upcoming birthdays" list, so both agree on
 * the one awkward case: a 29 February birthday is celebrated on 28 February in a non-leap year.
 */
final class BirthdayCalendar {

    private BirthdayCalendar() {
    }

    /** The calendar day this person's birthday falls on in {@code year}. */
    static LocalDate birthdayIn(LocalDate birthDate, int year) {
        if (birthDate.getMonth() == Month.FEBRUARY && birthDate.getDayOfMonth() == 29
                && !java.time.Year.isLeap(year)) {
            return LocalDate.of(year, Month.FEBRUARY, 28);
        }
        return LocalDate.of(year, birthDate.getMonth(), birthDate.getDayOfMonth());
    }

    /** The first birthday on or after {@code today}. */
    static LocalDate nextBirthday(LocalDate birthDate, LocalDate today) {
        LocalDate thisYear = birthdayIn(birthDate, today.getYear());
        return thisYear.isBefore(today) ? birthdayIn(birthDate, today.getYear() + 1) : thisYear;
    }

    /**
     * The inclusive day-of-month range to match against stored birth dates for a birthday "today": normally just
     * today's day, but on 28 February of a non-leap year it also covers 29 February.
     */
    static int[] dayRangeForToday(LocalDate today) {
        if (today.getMonth() == Month.FEBRUARY && today.getDayOfMonth() == 28 && !today.isLeapYear()) {
            return new int[] {28, 29};
        }
        return new int[] {today.getDayOfMonth(), today.getDayOfMonth()};
    }
}
